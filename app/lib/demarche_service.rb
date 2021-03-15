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

  def process_demarche(demarche_number, job)
    Rails.logger.tagged(@job[:name]) do
      demarche = Demarche.find_or_create_by({ id: demarche_number }) do |d|
        d.queried_at = EPOCH
        d.name = @job[:name]
      end
      start_time = Time.zone.now
      tasks = create_tasks(job)
      process_updated_dossiers(demarche, tasks)
      process_updated_tasks(demarche, tasks)
      demarche.queried_at = start_time
      demarche.save
      NotificationMailer.with(job: @job).job_report.deliver_now
    rescue => e
      Rails.logger.error(e.message + "\n" + e.backtrace.join('\n'))
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
    conditions = tasks.map do |task|
      TaskExecution
        .where.not(version: task.version)
        .where(job_tasks: { name: task.class.name.underscore })
    end
    tasks.each(&:before_run)
    conditions
      .reduce { |c1, c2| c1.or(c2) }
      .joins(:job_task)
      .where(job_tasks: { demarche_id: demarche.id })
      .each do |task_execution|
      on_dossier(task_execution.dossier) do |dossier|
        if dossier.present?
          process_dossier(dossier, tasks)
        else
          Check.where(dossier: task_execution.dossier).destroy_all
        end
      end
    end
    tasks.each(&:after_run)
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
    task_execution.version = task.version
    if task.valid?
      begin
        task.process_dossier(dossier)
      rescue StandardError => e
        task.add_message(Message::ERROR, "#{e.message}<br>\n#{e.backtrace.first}")
        Rails.logger.error("#{e.message}\n#{e.backtrace.join('\n')}")
        task_execution.failed = true
      end
      update_check_messages(task_execution, task)
      task_execution.save
    end
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
