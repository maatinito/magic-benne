# frozen_string_literal: true

class TaskExecutionsController < ApplicationController
  before_action :authenticate_user!

  def discard
    @task_execution = TaskExecution.find_by_id(params[:id])
    @task_execution&.discard
    redirect_to demarches_path
  end

  def undiscard
    @task_execution = TaskExecution.find(params[:id])
    @task_execution&.undiscard
    redirect_to demarches_path
  end

  def search
    @dossier_number = params[:q]
    @executions = TaskExecution.where(dossier: @dossier_number)
                               .joins(:job_task)
                               .includes(:job_task)
                               .left_outer_joins(:checksums)
                               .includes(:checksums)
                               .order('job_tasks.name ASC')
  end

  def reprocess
    @execution = TaskExecution.find_by_id(params[:id]) or not_found
    @execution.update!(reprocess: !@execution.reprocess)
    respond_to do |format|
      format.js
      format.html { 'coucou' }
    end
  end
end
