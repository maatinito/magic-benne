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
    Sentry.capture_exception(e)
    Rails.logger.error(e.message)
    e.backtrace.first(15).each { |bt| Rails.logger.error(bt) }
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

  def clean_task_executions(demarche_number, tasks)
    TaskExecution.joins(:job_task)
                 .where(job_tasks: { demarche_id: demarche_number })
                 .where.not(job_task: tasks.map(&:job_task)).destroy_all
  end

  def process_demarche(demarche_number, job)
    Rails.logger.tagged(@job[:name]) do
      demarche = DemarcheActions.get_demarche(demarche_number, @job[:name])
      start_time = Time.zone.now
      tasks = create_tasks(job)
      clean_task_executions(demarche_number, tasks)
      tasks.each(&:before_run)
      process_updated_dossiers(demarche, tasks)
      process_updated_tasks(demarche, tasks)
      tasks.each(&:after_run)
      demarche.queried_at = start_time
      demarche.save
      # NotificationMailer.with(job: @job).job_report.deliver_now
    rescue ExportError => e
      Rails.logger.error("#{e.message}\n#{e.backtrace.first(15).join("\n")}")
      NotificationMailer.with(message: e.message).report_error.deliver_later
    rescue StandardError => e
      Sentry.capture_exception(e)
      Rails.logger.error(e.message)
      e.backtrace.first(15).each { |bt| Rails.logger.error(bt) }
    end
  end

  def process_updated_dossiers(demarche, tasks)
    since = reset?(tasks) ? EPOCH : demarche.queried_at
    Rails.logger.info("Processing demarche #{demarche.id} #{demarche.name} since #{since}")
    # count = 0
    DossierActions.on_dossiers(demarche.id, since) do |dossier|
      # next if Rails.env.development? && (count += 1) > 10
      process_dossier(dossier, tasks)
    end
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
    Rails.logger.tagged('UpdatedTasks') do
      # count = 0
      updated_task_execution_query(demarche, tasks)
        .group_by(&:dossier)
        .each do |dossier_nb, task_executions|
        # next if Rails.env.development? && (count += 1) > 10

        DossierActions.on_dossier(dossier_nb) do |dossier|
          if dossier.present?
            apply_updated_tasks(dossier, task_executions, tasks)
          else
            Rails.logger.info("Dossier #{dossier_nb} plus accessible ==> Oublié")
            TaskExecution.where(dossier: dossier_nb).destroy_all
          end
        end
      end
    end
  end

  def apply_updated_tasks(dossier, task_executions, tasks)
    force_file_output_when_reprocess(task_executions)
    obsolete_task_names = Set.new(task_executions.map { |te| te.job_task.name })
    process_dossier(dossier, tasks.filter { |task| obsolete_task_names.include?(task.job_task.name) })
  end

  def force_file_output_when_reprocess(task_executions)
    Checksum.where(task_execution: task_executions.filter(&:reprocess)).destroy_all
  end

  def updated_task_execution_query(demarche, tasks)
    obsolete = tasks.map do |task|
      TaskExecution
        .where.not(version: task.version)
        .where(job_task: task.job_task)
    end
    reprocess = tasks.map do |task|
      TaskExecution
        .where(reprocess: true)
        .where(job_task: task.job_task)
    end
    (obsolete + reprocess)
      .reduce { |c1, c2| c1.or(c2) }
      .joins(:job_task)
      .where(job_tasks: { demarche_id: demarche.id })
  end

  def process_dossier(dossier, tasks)
    Rails.logger.info("Processing dossier #{dossier.number}")
    Rails.logger.tagged(dossier.number) do
      tasks.each do |task|
        Rails.logger.info("Processing task #{task.job_task.name}")
        Rails.logger.tagged(task.job_task.name) do
          task_execution = TaskExecution.find_or_create_by(dossier: dossier.number, job_task: task.job_task)
          apply_task(task, dossier, task_execution)
          task_execution.save
        end
      end
    end
  end

  def apply_task(task, dossier, task_execution)
    return unless task.valid?

    task_execution.version = task.version
    task.task_execution = task_execution
    begin
      task.process_dossier(dossier)
    rescue ExportError => e
      Rails.logger.error("#{e.message}\n#{e.backtrace.first(15).join("\n")}")
      task.add_message(Message::ERROR, e.message)
      task_execution.failed = true
    rescue StandardError => e
      Sentry.capture_exception(e)
      Rails.logger.error("#{e.message}\n#{e.backtrace.first(15).join("\n")}")
      task.add_message(Message::ERROR, "#{e.message}<br>\n#{backtrace(e)}")
      task_execution.failed = true
    end
    update_check_messages(task_execution, task)
    task_execution.reprocess = false
    task_execution.save
  end

  def backtrace(exception)
    exception.backtrace.filter { |b| b.include?('/app/') }.map { |b| b.gsub(%r{.*/app/}, 'app/') }.first(5).join("<br>\n")
  end

  def update_check_messages(task_execution, task)
    old_messages = Set[task_execution.messages.map(&:hashkey)]
    new_messages = Set[task.messages.map(&:hashkey)]
    return if old_messages == new_messages

    task_execution.messages.destroy(task_execution.messages.reject { |m| new_messages.include?(m.hashkey) })
    task_execution.messages << task.messages.reject { |m| old_messages.include?(m.hashkey) }
  end

  def create_tasks(job)
    taches = job['taches']
    return [] if taches.nil?

    taches.flatten.map.with_index do |task, i|
      case task
      when String
        Object.const_get(task.camelize).new(job, { position_: i })
      when Hash
        task.map { |name, params| Object.const_get(name.camelize).new(job, { position_: i }.merge(params)) }
      end
    end.flatten
  end

  def config
    file_mtime = File.mtime(config_file_name)
    return @config if @config.present? && @config_time >= file_mtime

    @config_time = file_mtime
    @config = YAML.safe_load(File.read(config_file_name), [], [], true)
  rescue StandardError => e
    NotificationMailer.with(message: "Impossible de lire le fichier de configuration: #{e.message}").report_error.deliver_later
    @config = {}
  end

  def config_file_name
    @config_file_name ||= Rails.root.join('storage', ENV.fetch('CONFIG', 'demarches.yml'))
  end
end
