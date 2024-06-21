# frozen_string_literal: true

require 'set'

class ExportDossiers < DossierTask
  def initialize(job, params)
    super
    @calculs = create_tasks
  end

  def required_fields
    super + %i[champs]
  end

  def authorized_fields
    super + %i[calculs fichier bloc]
  end

  def before_run
    @timestamp = Time.zone.now.strftime('%Y-%m-%d-%Hh%M')
    @calculs.each(&:before_run)
  end

  def run
    reset_csv
    if @params[:bloc]
      for_each_repetition(:bloc) do
        export
      end
    else
      export
    end
    csv&.flush
    Rails.logger.info("Dossier #{dossier.number} sauvegardé dans #{@current_path}.")
  end

  def export
    compute_dynamic_fields
    line = get_fields(params[:champs])
    save_csv(line)
  end

  def after_run
    @calculs.each(&:after_run)
    @csv&.close
  end

  def version
    super + 1
  end

  private

  def reset_csv
    return if @csv.nil? || @current_path == output_path

    @csv.close unless @csv.closed?
    @csv = nil
  end

  def csv
    return @csv unless @csv.nil?

    @current_path = output_path
    FileUtils.mkpath(output_dir)
    @csv = CSV.open(@current_path, 'wb', headers: column_names, write_headers: true, col_sep: ';')
  end

  def save_csv(line)
    csv << normalize_line_for_csv(line)
  end

  def column_names
    params[:champs].map do |elt|
      case elt
      when Hash
        elt['colonne']
      when String
        elt
      end
    end
  end

  def output_path
    file_template = @params[:fichier]
    if file_template.present?
      variables = { timestamp: @timestamp }.merge(@params)
      path = StringTemplate.new(FieldSource.new(@dossier, variables)).instanciate_filename(file_template)
      "#{output_dir}/#{path}"
    else
      "#{output_dir}/#{demarche_dir}-#{demarche_id}-#{Time.zone.now.strftime('%Y-%m-%d-%Hh%M')}.csv"
    end
  end

  def normalize_line_for_csv(line)
    line.map do |cells|
      cells = Array(cells)
      cells.map! do |v|
        case v
        when DateTime
          v.iso8601
        when Date
          v.strftime('%d/%m/%Y')
        else
          v
        end
      end
      cells.join('|').strip.tr(';', '/')
    end
  end

  def get_fields(fields)
    fields.map(&method(:get_field))
  end

  def get_field(param)
    field, par_defaut = definition(param)
    return par_defaut unless field

    value = @computed[field] if @computed.is_a? Hash
    return value if value.present?

    champs = object_values(@dossier, field, log_empty: false)
    return champs_to_values(champs) if champs.present?

    add_message(Message::WARN, "Impossible de trouver le champ #{field}") unless par_defaut
    par_defaut
  end

  def definition(param)
    if param.is_a?(Hash)
      par_defaut = param['par_defaut'] || ''
      field = param['champ']
    else
      field = param.to_s
      par_defaut = ''
    end
    [field, par_defaut]
  end

  def compute_dynamic_fields
    @computed = compute_cells if @calculs.present?
  end

  def compute_cells
    @calculs.map { |task| task.process_dossier(@dossier) || {} }.reduce(&:merge)
  end

  def create_tasks
    taches = params[:calculs]
    return [] if taches.nil?

    taches.flatten.map do |task|
      case task
      when String
        Object.const_get(task.camelize).new(job, {})
      when Hash
        task.map { |name, params| Object.const_get(name.camelize).new(@job, params || {}) }
      end
    end.flatten
  end
end
