# frozen_string_literal: true

require 'net/ftp'

class FileTransfer < DossierTask
  include Utils

  def version
    super + 2
  end

  def required_fields
    super + %i[api_cle api_secret identifiant mot_de_passe taches]
  end

  def authorized_fields
    super + %i[tenant]
  end

  def run; end

  def after_run
    tenant = params[:tenant]&.to_sym || :default
    Rails.logger.debug ("Initializing connection to TransfertPro #{tenant} tenant")
    @tp = FileTransfer::tp_api(params[:api_cle], params[:api_secret], tenant)
    @tp.connect(params[:identifiant], params[:mot_de_passe])

    execute_tasks
  end

  def self.tp_api(api_key, api_secret, tenant)
    Transfertpro::FileSystem.new(api_key, api_secret, tenant)
  end

  private

  def execute_tasks
    @tasks = params[:taches]
    @tasks.each do |task|
      case task.first[0]
      when 'telecharger'
        download(task)
      when 'televerser'
        upload(task)
      when 'effacer'
        delete(task)
      else
        throw ExportError.new("Instruction de transfer ftp inconnue #{task.first[0]}")
      end
    end
  end

  def download(task)
    move_files = %w[true oui].include?(task['deplacer']&.downcase)
    pattern = task.first[1]
    path = File.dirname(pattern)
    basename = File.basename(pattern)
    to = task['vers'] || '.'
    Rails.logger.debug((move_files ? 'Moving' : 'Downloading') + " #{pattern} to local #{to}")
    begin
      files = @tp.download_shared_files(path, basename, to, move: move_files)
      Rails.logger.info("Files downloaded from TransfertPro directory #{to}: #{files.join(',')}")
    rescue StandardError => e
      log_error("Error downloading #{pattern} from #{params[:serveur]}", e)
    end
  end

  def log_error(message, exception)
    message = "#{message}: #{exception.message}"
    Rails.logger.error(message)
    exception.backtrace.first(15).each { |bt| Rails.logger.error(bt) }
    # NotificationMailer.with(message:).report_error.deliver_later
  end

  def upload(task)
    move_files = %w[true oui].include?(task['deplacer']&.downcase)
    pattern = task.first[1]
    to = task['vers']
    Rails.logger.debug((move_files ? 'Moving' : 'Uploading') + " #{pattern} to remote #{to}")
    begin
      files = @tp.upload_shared_files(File.dirname(pattern), File.basename(pattern), to, move: move_files)
      Rails.logger.info("Files uploaded on TransfertPro directory #{to}: #{files.join(',')}")
    rescue StandardError => e
      log_error("Error uploading #{pattern} to #{@params[:tenant]} TransfertPro using #{@params[:identifiant]}", e)
    end
  end

  def delete(task)
    pattern = task.first[1]
    path = File.dirname(pattern)
    pattern = File.basename(pattern)
    Rails.logger.debug("Deleting remote pattern #{pattern}")
    deleted = @tp.delete_shared_files(path, pattern)
    Rails.logger.info("Files deleted on TransfertPro directory #{path}: #{deleted.join(',')}")
  end
end
