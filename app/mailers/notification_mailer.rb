# frozen_string_literal: true

class NotificationMailer < ApplicationMailer
  def job_report
    @job = params[:job]
    demarche_id = @job[:demarche]
    @executions = TaskExecution
                  .order('task_executions.updated_at desc')
                  .where(failed: true)
                  .includes(:messages)
                  .includes(job_task: :demarche)
                  .joins(job_task: :demarche)
                  .where('demarches.id': demarche_id)
                  .each_with_object({}) do |te, h|
      h.update(te.job_task.demarche => { te.dossier => [te] }) do |_, h1, h2|
        h1.update(h2) do |_, l1, l2|
          l1 + l2
        end
      end
    end
    mail(to: email, subject: "SefiDem #{@job[:name]}")
  end

  private

  def email
    @job[:email] || 'clautier@idt.pf'
  end
end
