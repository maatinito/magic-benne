# frozen_string_literal: true

# controller to trigger CSV exports
#
class DemarchesController < ApplicationController
  def export
    ExportJob.run(false, 'storage/demarches.yml')
    redirect_to demarches_main_path
  end

  def export_all
    ExportJob.run(true, 'storage/demarches.yml')
    redirect_to demarches_main_path
  end

  def main
    @running = ExportJob.running?
    puts "Job running=#{@running}"

    @executions = TaskExecution
                  .order('task_executions.updated_at desc')
                  .where(id: Message.select(:task_execution_id))
                  .includes(:messages)
                  .includes(job_task: :demarche)
                  .each_with_object({}) do |te, h|
      h.update(te.job_task.demarche => { te.dossier => [te] }) do |_, h1, h2|
        h1.update(h2) do |_, l1, l2|
          l1 + l2
        end
      end
    end
  end
end
