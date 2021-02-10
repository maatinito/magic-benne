# frozen_string_literal: true

class Task
  attr_reader :params, :demarche_id, :demarche_dir, :output_dir, :job_task
  attr_writer :errors, :demarche_id

  def initialize(job, params)
    @job = job.symbolize_keys
    @params = @job.merge(params.symbolize_keys)
    @demarche_id = @params[:demarche]
    @output_dir = @params[:rep_sortie] || 'storage'

    @errors = []
    missing_fields = (required_fields - @params.keys)
    if missing_fields.present?
      @errors << "Les champs #{missing_fields.join(',')} devrait être définis sur #{self.class.name.underscore}"
    end
    unknown_fields = @params.keys - authorized_fields - required_fields - @job.keys
    if unknown_fields.present?
      @errors << "#{unknown_fields.join(',')} n'existe(nt) pas sur #{self.class.name.underscore}"
    end
    @accessed_fields = Set[]
    @demarche = Demarche.find_or_create_by(id: demarche_id)
    @demarche_title = DemarcheActions.title(demarche_id)
    @demarche_dir = ActiveStorage::Filename.new(@job[:nom_demarche] || @demarche_title).sanitized
    @job_task = JobTask.find_or_create_by(demarche: @demarche, name: self.class.name.underscore)
  end

  def valid?
    @errors.blank?
  end

  def required_fields
    []
  end

  def authorized_fields
    [:output_dir]
  end
end