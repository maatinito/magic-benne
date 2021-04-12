# frozen_string_literal: true

require 'set'

class DossierTask < Task
  attr_reader :dossier, :exception
  attr_accessor :task_execution

  def process_dossier(dossier)
    @dossier = dossier
    @messages = []
    run if dossier_has_right_state
  end

  def authorized_fields
    super + %i[etat_du_dossier]
  end

  def dossier_has_right_state
    @states ||= [*@params[:etats_du_dossier]].flat_map { |s| s.split(',') }.to_set
    @states.empty? || @states.include?(@dossier.state)
  end

  def run
    raise "Should be implemented by class #{self}"
  end

  def before_run; end

  def after_run; end

  def version
    1.0
  end

  def add_message(level, message)
    @messages << Message.new(level: level, message: message)
    Rails.logger.info("Dossier: #{@dossier_nb}: #{message}")
    failed = true if level == Message::ERROR
  end

  def dedupe(filename)
    overwritten = File.exist?(filename)
    yield
    Checksum.dedupe(@task_execution, filename) unless overwritten
  end

  private

  def field_values(field)
    return nil if @dossier.nil? || field.blank?

    objects = [*@dossier]
    field.split(/\./).each do |name|
      objects = objects.flat_map { |object| object.champs.select { |champ| champ.label == name } }
      Rails.logger.warn("Sur le dossier #{@dossier.number}, le champ #{field} est vide.") if objects.blank?
    end
    objects
  end

  def field_value(field_name)
    field_values(field_name)&.first
  end

  def param_values(param_name)
    field_values(@params[param_name])
  end

  def param_value(param_name)
    param_values(param_name)&.first
  end

  def set_variable(variable, value)
    attribute = Attribute.find_or_create_by(dossier: @dossier_nb, task: self.class.name.underscore, variable: variable)
    attribute.value = value
    attribute.save
  end

  def get_variable(variable)
    Attribute.find_by(dossier: @dossier_nb, task: self.class.name.underscore, variable: variable)&.value
  end
end
