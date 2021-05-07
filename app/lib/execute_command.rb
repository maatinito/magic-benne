require 'open3'

class ExecuteCommand < DossierTask

  def version
    super + 1
  end

  def required_fields
    super + %i[commande]
  end

  def authorized_fields
    super + %i[alerte]
  end

  def before_run
    @has_new_dossier = false
  end

  def run
    @has_new_dossier = true
  end

  def after_run
    return unless @has_new_dossier || ENV.fetch('FORCE_EXECUTION', nil)

    command = params[:commande]
    stdout, stderr, status = Open3.capture3(command)
    if status.exitstatus != 0
      NotificationMailer.with(message: stderr + "\n\nSortie\n" + stdout).report_error.deliver_later
    end
  end
end