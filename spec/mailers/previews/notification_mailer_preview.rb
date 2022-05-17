# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/notification_mailer
class NotificationMailerPreview < ActionMailer::Preview
  def job_report
    job = {
      demarche: 810,
      name: 'CSE'
    }
    NotificationMailer.with(job:).job_report
  end

  def output_dir_not_accessible
    NotificationMailer.output_dir_not_accessible
  end
end
