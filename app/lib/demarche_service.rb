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
      job['name'] = job_name
      @job = job
      process_demarche(demarche_number, job)
    end
  end

  EPOCH = Time.zone.parse('2000-01-01 00:00')

  private

  def process_demarche(demarche_number, job)
    demarche = Demarche.find_or_create_by({ id: demarche_number }) do |d|
      d.queried_at = EPOCH
    end
    start_time = Time.zone.now
    tasks = create_tasks(job)
    since = reset?(tasks) ? EPOCH : demarche.queried_at
    tasks.each(&:before_run)
    # count = 0
    DossierActions.on_dossiers(demarche.id, since) do |dossier|
      process_dossier(dossier, tasks)
      # break if (count=count+1) > 10
    end
    tasks.each(&:after_run)
    demarche.queried_at = start_time
    demarche.save
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

  def process_dossier(dossier, tasks)
    tasks.each do |task|
      task_execution = TaskExecution.find_or_create_by(dossier: dossier.number, job_task: task.job_task)
      apply_task(task, dossier, task_execution)
      task_execution.save
    end
  end

  def apply_task(task, dossier, task_execution)
    task_execution.version = task.version
    if task.valid?
      task.process_dossier(dossier)
      if task_execution.failed = task.exception.present?
        Rails.logger.error(task.exception)
        Rails.logger.debug(task.exception.backtrace)
      end
    end
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
