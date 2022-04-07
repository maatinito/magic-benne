# frozen_string_literal: true

# controller to trigger CSV exports
#
class DemarchesController < ApplicationController
  before_action :authenticate_user!

  def export
    ExportJob.run(false)
    redirect_to demarches_main_path
  end

  def export_all
    ExportJob.run(true)
    redirect_to demarches_main_path
  end

  def clear_checksums
    Checksum.clear_all
    redirect_to demarches_main_path
  end

  def show
    @with_discarded = session[:with_discarded].present?
    @running = ExportJob.running?
    demarche_id = params[:demarche]
    @demarche = Demarche.find_by_id(demarche_id) if demarche_id.present?
    @demarche ||= last_processed_demarche

    @dossiers = dossiers_for_current_demarche
    @demarches = demarche_list
  end

  def with_discarded
    if params[:with_discarded] == 'true'
      session[:with_discarded] = 'true'
    else
      session.delete(:with_discarded)
    end
    redirect_to demarches_main_path
  end

  private

  def dossiers_for_current_demarche
    return [] unless @demarche.present?

    (@with_discarded ? TaskExecution.discarded : TaskExecution.kept)
      .order('task_executions.updated_at desc')
      .joins(job_task: { demarche: :instructeurs })
      .where(demarches_users: { user_id: current_user })
      .where(job_tasks: { demarche: @demarche })
      .where(id: Message.select(:task_execution_id))
      .includes(:messages)
      .includes(:job_task)
      .group_by(&:dossier)
  end

  def demarche_list
    TaskExecution
      .where(id: Message.select(:task_execution_id))
      .joins(job_task: :demarche)
      .distinct
      .group('demarches.id', 'demarches.name')
      .count(:dossier)
  end

  def last_processed_demarche
    TaskExecution.order('task_executions.updated_at desc').joins(:messages).first.job_task.demarche
  end
end
