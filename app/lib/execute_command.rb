# frozen_string_literal: true

require 'open3'

class ExecuteCommand < DossierTask
  def version
    super + 2
  end

  def required_fields
    super + %i[commande]
  end

  def authorized_fields
    super + %i[alerte]
  end

  def run; end

  def after_run
    command = params[:commande]
    Rails.logger.info("Executing: #{command}")
    stdout, stderr, status = Open3.capture3(command)
    Rails.logger.debug("Stdout: #{stdout}")
    Rails.logger.debug("Stderr: #{stderr}")
    NotificationMailer.with(message: "#{stderr}\n\nSortie\n#{stdout}").report_error.deliver_later if status.exitstatus != 0
  end
end
