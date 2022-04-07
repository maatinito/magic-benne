# frozen_string_literal: true

# controller to trigger CSV exports
#
class DemarchesController < ApplicationController
  before_action :authenticate_user!

  def export
    ExportJob.run(false)
    redirect_to demarches_path
  end

  def export_all
    ExportJob.run(true)
    redirect_to demarches_path
  end

  def clear_checksums
    Checksum.clear_all
    redirect_to demarches_path
  end

  def show
    @with_discarded = session[:with_discarded].present?
    @running = ExportJob.running?
    @demarches = demarche_list
    @demarche = current_demarche
    @dossiers = dossiers_for_current_demarche
  end

  def with_discarded
    if params[:with_discarded] == 'true'
      session[:with_discarded] = 'true'
    else
      session.delete(:with_discarded)
    end
    redirect_to demarches_path(params[:demarche])
  end

  private

  def current_demarche
    demarche_id = (params[:demarche].presence || session[:demarche])&.to_i
    if demarche_id.present? && @demarches.any? { |demarche, _count| demarche[0] == demarche_id }
      demarche = Demarche.find_by_id(demarche_id)
      if demarche.present?
        session[:demarche] = demarche.id.to_s
      else
        session.delete(:demarche)
      end
    end
    demarche || last_processed_demarche
  end

  def dossiers_for_current_demarche
    return [] unless @demarche.present?

    task_executions
      .order('task_executions.updated_at desc')
      .joins(job_task: { demarche: :instructeurs })
      .where(demarches_users: { user_id: current_user })
      .where(job_tasks: { demarche: @demarche })
      .where(id: Message.select(:task_execution_id))
      .includes(:messages)
      .includes(:job_task)
      .group_by(&:dossier)
  end

  def task_executions
    @with_discarded ? TaskExecution.discarded : TaskExecution.kept
  end

  def demarche_list
    task_executions
      .where(id: Message.select(:task_execution_id))
      .joins(job_task: { demarche: :instructeurs })
      .where(demarches_users: { user_id: current_user })
      .distinct
      .group('demarches.id', 'demarches.name')
      .count(:dossier)
  end

  def last_processed_demarche
    TaskExecution.order('task_executions.updated_at desc').joins(:messages).first.job_task.demarche
  end
end
