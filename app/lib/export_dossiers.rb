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
    super + %i[calculs]
  end

  def run
    fields = params[:champs]
    line = get_fields(fields)
    add_dynamic_columns(line)
    @dossiers << line
  end

  def before_run
    @dossiers = []
    @dynamic_titles = Set.new
    @calculs.each(&:before_run)
  end

  def after_run
    @calculs.each(&:after_run)
    # pp @dossiers
    return if params[:champs].blank? || @dossiers.blank?

    titles = ['ID'] + params[:champs]
    task_output_dir = "#{output_dir}/#{@demarche_dir}"
    FileUtils.mkpath(task_output_dir)
    output_path = "#{task_output_dir}/#{Time.zone.now.strftime('dossiers %Y-%m-%d-%Hh%M')}.csv"
    CSV.open(output_path, 'wb', headers: titles + @dynamic_titles.to_a, write_headers: true, col_sep: ';') do |csv|
      @dossiers.each { |line| csv << line }
    end
  end

  def version
    1.0
  end

  private

  MD_FIELDS =
    {
      'ID' => 'number',
      'Email' => 'usager.email',
      'Entreprise raison sociale' => 'demandeur.entreprise.raison_sociale',
      'Archivé' => 'archived',
      'État du dossier' => 'state',
      'Dernière mise à jour le' => 'date_derniere_modification',
      'Déposé le' => 'date_passage_en_construction',
      'Passé en instruction le' => 'date_passage_en_instruction',
      'Traité le' => 'date_traitement',
      'Motivation de la décision' => 'motivation',
      'Instructeurs' => 'groupe_instructeur.instructeurs.email'
    }.freeze

  def get_fields(fields)
    line = [dossier.number] + fields.map do |field|
      if (path = MD_FIELDS[field]).present?
        dossier_field_values(path)
      else
        field_values(field).map(&method(:champ_value)).compact.join('|')
      end
    end
  end

  def dossier_field_values(path)
    path.split(/\./).reduce(@dossier) do |o, f|
      case o
      when GraphQL::Client::List
        o.map { |elt| elt.send(f) }
      else
        o.send(f) if o.present?
      end
    end
  end

  def champ_value(champ)
    case champ.__typename
    when 'TextChamp', 'IntegerNumberChamp', 'DecimalNumberChamp', 'CiviliteChamp'
      champ.value || ''
    when 'MultipleDropDownListChamp'
      champ.values
    when 'LinkedDropDownListChamp'
      "#{champ.primary_value}/#{champ.secondary_value}"
    when 'DateChamp'
      Date.iso8601(champ.value).strftime('%d/%m/%Y %H:%M')
    when 'CheckboxChamp'
      puts champ.value
    when 'NumeroDnChamp'
      "#{champ.numero_dn}|#{champ.date_de_naissance}"
    when 'DossierLinkChamp'
      champ.string_value
    when 'PieceJustificativeChamp'
      champ.file.filename
    when 'SiretChamp'
      champ.string_value
    else
      puts champ.__typename
    end
  end

  def add_dynamic_columns(line)
    if @calculs.present?
      dynamic_cells = compute_cells
      @dynamic_titles.merge dynamic_cells.keys if dynamic_cells.present?
      @dynamic_titles.each { |column| line << (dynamic_cells[column] || '') }
    end
  end

  def compute_cells
    @calculs.map { |task| task.process_dossier(@dossier) }.reduce(&:merge)
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
