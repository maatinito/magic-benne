# frozen_string_literal: true

class TaskExecutionsController < ApplicationController
  def discard
    @task_execution = TaskExecution.find_by_id(params[:id])
    @task_execution&.discard
    redirect_to demarches_main_path
  end

  def undiscard
    @task_execution = TaskExecution.with_discarded.find(params[:id])
    @task_execution&.undiscard
    redirect_to demarches_main_path
  end
end
