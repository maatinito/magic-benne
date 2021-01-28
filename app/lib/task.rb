# frozen_string_literal: true

class Task
  attr_reader :errors, :params, :demarche_id, :output_dir, :job_task

  def initialize(job, params)
    @job = job
    @demarche_id = @job['demarche']
    @output_dir = @job['output_dir'] || 'storage'
    @errors = []
    @params = params.symbolize_keys
    missing_fields = (required_fields - @params.keys)
    if missing_fields.present?
      @errors << "Les champs #{missing_fields.join(',')} devrait être définis sur #{self.class.name.underscore}"
    end
    unknown_fields = @params.keys - authorized_fields - required_fields
    if unknown_fields.present?
      @errors << "#{unknown_fields.join(',')} n'existe(nt) pas sur #{self.class.name.underscore}"
    end
    @accessed_fields = Set[]
    @demarche = Demarche.find_or_create_by(id: demarche_id)
    @job_task = JobTask.find_or_create_by(demarche: @demarche, name: self.class.name.underscore)
  end

  def valid?
    @errors.blank?
  end

  def required_fields
    []
  end

  def authorized_fields
    []
  end
end
