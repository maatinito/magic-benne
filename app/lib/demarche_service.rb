# frozen_string_literal: true

# service to download dossier report and save them in common format

require 'tempfile'
require 'open-uri'
require 'roo'
require 'fileutils'

class DemarcheService
  @config = nil
  @config_time = nil

  def initialize(reset: false, config_file: nil)
    @reset = reset
    @config_file_name = config_file
  end

  def process
    return unless output_dir_accessible

    config.filter { |_k, d| d.key? 'taches' }.each do |job_name, job|
      demarche_number = job['demarche']
      job[:name] = job_name
      @job = job.symbolize_keys
      process_demarche(demarche_number, job)
    end
  rescue StandardError => e
    pp e
    pp e.backtrace
  end

  EPOCH = Time.zone.parse('2000-01-01 00:00')

  private

  def output_dir_accessible
    output_dir = config.dig('par_defaut', 'rep_sortie')
    return true unless output_dir

    begin
      f = File.open("#{output_dir}/test.txt", 'w+')
      f.write 'test'
      f.close
      File.delete(f)
      true
    rescue Errno::ENOENT
      NotificationMailer.output_dir_not_accessible.deliver_later
      false
    end
  end

  def process_demarche(demarche_number, job)
    Rails.logger.tagged(@job[:name]) do
      demarche = DemarcheActions.get_demarche(demarche_number, @job[:name])
      start_time = Time.zone.now
      tasks = create_tasks(job)
      process_updated_dossiers(demarche, tasks)
      process_updated_tasks(demarche, tasks)
      demarche.queried_at = start_time
      demarche.save
      NotificationMailer.with(job: @job).job_report.deliver_now
    rescue StandardError => e
      Rails.logger.error("#{e.message}\n#{e.backtrace.join('\n')}")
    end
  end

  def process_updated_dossiers(demarche, tasks)
    since = reset?(tasks) ? EPOCH : demarche.queried_at
    tasks.each(&:before_run)
    count = 0
    DossierActions.on_dossiers(demarche.id, since) do |dossier|
      Rails.logger.tagged(dossier.number) do
        next if (count += 1) > 1_000_000

        process_dossier(dossier, tasks)

        GC.compact
      end
    end
    tasks.each(&:after_run)
  end

  def reset?(tasks)
    @reset || tasks.find { |task| TaskExecution.find_by(job_task: task.job_task).nil? }.present?
  end

  # def process_failed_executions(tasks)
  #   job_tasks = tasks.map { |task| [task.job_task, task] }.to_h
  #   TaskExecution.joins(:job_task).where(failed: true, job_task: job_tasks.keys).includes(:job_task).each do |task_execution|
  #     on_dossier(task_execution.dossier) do |md_dossier|
  #       process_dossier(md_dossier, job_tasks[task_execution.job_task])
  #     end
  #   end
  # end

  def process_updated_tasks(demarche, tasks)
    tasks.each(&:before_run)
    updated_task_execution_query(demarche, tasks)
      .group_by(&:dossier)
      .each do |dossier_nb, task_executions|
      on_dossier(dossier_nb) do |dossier|
        if dossier.present?
          apply_updated_tasks(dossier, task_executions, tasks)
        else
          TaskExecution.where(dossier: dossier_nb).destroy_all
        end
      end
    end
    tasks.each(&:after_run)
  end

  def apply_updated_tasks(dossier, task_executions, tasks)
    if dossier.present?
      task_names = Set.new(task_executions.map { |te| te.job_task.name })
      process_dossier(dossier, tasks.filter { |task| task_names.include?(task.class.name.underscore) })
    else
      TaskExecution.where(dossier: dossier).destroy_all
    end
  end

  def updated_task_execution_query(demarche, tasks)
    conditions = tasks.map do |task|
      TaskExecution
        .where.not(version: task.version)
        .where(job_tasks: { name: task.class.name.underscore })
    end
    conditions
      .reduce { |c1, c2| c1.or(c2) }
      .joins(:job_task)
      .where(job_tasks: { demarche_id: demarche.id })
  end

  def process_dossier(dossier, tasks)
    tasks.each do |task|
      Rails.logger.tagged(task.class.name) do
        task_execution = TaskExecution.find_or_create_by(dossier: dossier.number, job_task: task.job_task)
        apply_task(task, dossier, task_execution)
        task_execution.save
      end
    end
  end

  def apply_task(task, dossier, task_execution)
    return unless task.valid?

    task_execution.version = task.version
    task.task_execution = task_execution
    begin
      task.process_dossier(dossier)
    rescue StandardError => e
      task.add_message(Message::ERROR, "#{e.message}<br>\n#{e.backtrace.first}")
      Rails.logger.error("#{e.message}\n#{e.backtrace.first(10).join('\n')}")
      task_execution.failed = true
    end
    update_check_messages(task_execution, task)
    task_execution.save
  end

  def update_check_messages(task_execution, task)
    old_messages = Set[task_execution.messages.map(&:hashkey)]
    new_messages = Set[task.messages.map(&:hashkey)]
    return if old_messages == new_messages

    task_execution.messages.destroy(task_execution.messages.reject { |m| new_messages.include?(m.hashkey) })
    task_execution.messages << task.messages.reject { |m| old_messages.include?(m.hashkey) }
  end

  def on_dossier(dossier_number)
    result = MesDemarches::Client.query(MesDemarches::Queries::Dossier,
                                        variables: { dossier: dossier_number })
    dossier = (data = result.data) ? data.dossier : nil
    yield dossier
    Rails.logger.error(result.errors.values.join(',')) unless data
  end

  def create_tasks(job)
    taches = job['taches']
    return [] if taches.nil?

    taches.flatten.map do |task|
      case task
      when String
        Object.const_get(task.camelize).new(job, {})
      when Hash
        task.map { |name, params| Object.const_get(name.camelize).new(job, params || {}) }
      end
    end.flatten
  end

  def config
    file_mtime = File.mtime(config_file_name)
    if @config.nil? || @config_time < file_mtime
      @config = YAML.safe_load(File.read(config_file_name), [], [], true)
      @config_time = file_mtime
    end
    @config
  end

  def config_file_name
    @config_file_name ||= Rails.root.join('storage', 'demarches.yml')
  end
end
