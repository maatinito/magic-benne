# frozen_string_literal: true

require 'net/ftp'

class FileTransfer < DossierTask
  include Utils

  def version
    super + 1
  end

  def required_fields
    super + %i[serveur identifiant mot_de_passe taches]
  end

  def authorized_fields
    super + %i[port]
  end

  def run; end

  def after_run
    host = params[:serveur]
    Rails.logger.tagged(host) do
      user = params[:identifiant]
      password = params[:mot_de_passe]
      port = params[:port] || '21'
      @ftp = Net::FTP.new(host, port:, username: user, password:, ssl: port == '21')
      execute_tasks
    end
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
    localfile = nil
    begin
      @ftp.chdir(path) if path.present?
      @ftp.nlst(basename).each do |filename|
        localfile = "#{to}/#{filename}"
        Rails.logger.debug("Downloading #{filename} to #{localfile}")
        @ftp.getbinaryfile(filename, localfile)
        delete_remote_file(filename, localfile, pattern) if move_files
      end
    rescue StandardError => e
      # File.delete(localfile) if localfile
      log_error("Error downloading #{pattern} from #{params[:serveur]}", e)
    end
  end

  def log_error(message, exception)
    message = "#{message}: #{exception.message}"
    Rails.logger.error(message)
    exception.backtrace.first(15).each { |bt| Rails.logger.error(bt) }
    NotificationMailer.with(message:).report_error.deliver_later
  end

  def delete_remote_file(filename, localfile, pattern)
    if File.new(localfile).size == @ftp.size(filename)
      Rails.logger.debug("Deleting remote #{filename}")
      @ftp.delete(filename)
    else
      message = "Problème sur le transfert du fichier #{filename} (#{pattern} sur #{params[:serveur]}}. " \
                "Taille du fichier en local: #{File.new(localfile).size}. " \
                "Taille du fichier distant: #{@ftp.size(filename)}"
      Rails.logger.error(message)
      NotificationMailer.with(message:).report_error.deliver_later if @ftp.closed?
      # File.delete(localfile)
    end
  end

  def upload(task)
    move_files = %w[true oui].include?(task['deplacer']&.downcase)
    pattern = task.first[1]
    to = task['vers']
    Rails.logger.debug((move_files ? 'Moving' : 'Uploading') + " #{pattern} to remote #{to}")
    remote_filename = nil
    begin
      @ftp.chdir(to) if to.present?
      Dir.glob(pattern).each do |filename|
        remote_filename = File.basename(filename)
        Rails.logger.debug("Uploading #{filename} to #{to}")
        @ftp.putbinaryfile(filename)
        delete_local_file(filename) if move_files
      end
    rescue StandardError => e
      # @ftp.delete(remote_filename) if remote_filename rescue 'ignore'
      log_error("Error uploading #{pattern} to #{params[:serveur]}", e)
    end
  end

  def delete_local_file(filename)
    basename = File.basename(filename)
    if File.new(filename).size == @ftp.size(basename)
      Rails.logger.debug("Deleting local #{filename}")
      File.delete(filename)
    else
      message = "Problème sur le transfert du fichier #{filename} (#{params[:serveur]}}. " \
                "Taille du fichier en local: #{File.new(filename).size}. " \
                "Taille du fichier distant: #{@ftp.size(basename)}"
      Rails.logger.error(message)
      NotificationMailer.with(message:).report_error.deliver_later if @ftp.closed?
      # @ftp.delete(@basename) rescue 'ignore'
    end
  end

  def delete(task)
    pattern = task.first[1]
    path = File.dirname(pattern)
    basename = File.basename(pattern)
    @ftp.chdir(path) if path.present?
    Rails.logger.debug("Deleting remote pattern #{pattern}")
    @ftp.nlst(basename).each do |filename|
      Rails.logger.debug("Deleting remote #{filename}")
      @ftp.delete(filename)
    end
  end
end
