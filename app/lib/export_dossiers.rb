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
    compute_dynamic_fields
    line = get_fields(params[:champs])
    @dossiers << line
  end

  def before_run
    @dossiers = []
    @calculs.each(&:before_run)
  end

  def after_run
    @calculs.each(&:after_run)
    # pp @dossiers
    return if params[:champs].blank? || @dossiers.blank?

    normalize_cells

    FileUtils.mkpath(output_dir)
    CSV.open(output_path, 'wb', headers: column_names, write_headers: true, col_sep: ';') do |csv|
      @dossiers.each { |line| csv << line }
    end
  end

  def version
    super + 1
  end

  private

  def column_names
    ['ID'] + params[:champs].map do |elt|
      case elt
      when Hash
        elt['colonne']
      when String
        elt
      end
    end
  end

  def output_path
    "#{output_dir}/#{@demarche_dir}-#{demarche_id}-#{Time.zone.now.strftime('%Y-%m-%d-%Hh%M')}.csv"
  end

  def normalize_cells
    @dossiers.map! do |line|
      line.map do |cell|
        cell.is_a?(String) ? cell.strip.tr(';', '/') : cell
      end
    end
  end

  MD_FIELDS =
    {
      'ID' => 'number',
      'Email' => 'usager.email',
      'Archivé' => 'archived',
      'Civilité' => 'demandeur.civilite',
      'Nom' => 'demandeur.nom',
      'Prénom' => 'demandeur.prenom',
      'État du dossier' => 'state',
      'Dernière mise à jour le' => 'date_derniere_modification',
      'Déposé le' => 'date_passage_en_construction',
      'Passé en instruction le' => 'date_passage_en_instruction',
      'Traité le' => 'date_traitement',
      'Motivation de la décision' => 'motivation',
      'Instructeurs' => 'groupe_instructeur.instructeurs.email',
      'Établissement Numéro TAHITI' => 'demandeur.siret',
      'Établissement siège social' => '', # not implemented in Mes-Démarches
      'Établissement NAF' => 'demandeur.naf',
      'Établissement libellé NAF' => 'demandeur.libelle_naf',
      'Établissement Adresse' => 'demandeur.adresse',
      'Établissement numero voie' => 'demandeur.numero_voie',
      'Établissement type voie' => 'demandeur.type_voie',
      'Établissement nom voie' => 'demandeur.nom_voie',
      'Établissement complément adresse' => 'demandeur.complement_adresse',
      'Établissement code postal' => 'demandeur.code_postal',
      'Établissement localité' => 'demandeur.localite',
      'Établissement code INSEE localité' => '', # not implemented in Mes-Démarches
      'Entreprise SIREN' => 'demandeur.entreprise.siren',
      'Entreprise capital social' => 'demandeur.entreprise.capital_social',
      'Entreprise numero TVA intracommunautaire' => 'demandeur.entreprise.numero_tva_intracommunautaire',
      'Entreprise forme juridique' => 'demandeur.entreprise.forme_juridique',
      'Entreprise forme juridique code' => 'demandeur.entreprise.forme_juridique_code',
      'Entreprise nom commercial' => 'demandeur.entreprise.nom_commercial',
      'Entreprise raison sociale' => 'demandeur.entreprise.raison_sociale',
      'Entreprise Numéro TAHITI siège social' => 'demandeur.entreprise.siret_siege_social',
      'Entreprise code effectif entreprise' => 'demandeur.entreprise.code_effectif_entreprise',
      'Entreprise date de création' => 'demandeur.entreprise.date_creation',
      'Entreprise nom' => 'demandeur.entreprise.nom',
      'Entreprise prénom' => 'demandeur.entreprise.prenom',
      'Association RNA' => 'demandeur.association.rna',
      'Association titre' => 'demandeur.association.titre',
      'Association objet' => 'demandeur.association.objet',
      'Association date de création' => 'demandeur.association.date_creation',
      'Association date de déclaration' => 'demandeur.association.date_declaration',
      'Association date de publication' => 'demandeur.association.date_declaration'
    }.freeze

  def get_fields(fields)
    [dossier.number] + fields.map(&method(:get_field))
  end

  def get_field(param)
    case param
    when String
      field = param
      par_defaut = ''
    when Hash
      par_defaut = param['par_defaut'] || ''
      field = param['champ']
    end
    if field
      values = @computed[field] if @computed.is_a? Hash
      if values
        values.is_a?(Array) ? values.join('|') : values
      elsif (values = field_values(field, log_empty: false) + annotation_values(field, log_empty: false)).present?
        values.map(&method(:champ_value)).compact.select(&:present?).join('|')
      elsif (path = MD_FIELDS[field]).present?
        dossier_field_values(path)
      else
        add_message(Message::WARN, "Impossible de trouver le champ #{field}")
      end
    else
      par_defaut
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
    return nil unless champ

    case champ.__typename
    when 'TextChamp', 'IntegerNumberChamp', 'DecimalNumberChamp', 'CiviliteChamp'
      champ.value || ''
    when 'MultipleDropDownListChamp'
      champ.values
    when 'LinkedDropDownListChamp'
      "#{champ.primary_value}/#{champ.secondary_value}"
    when 'DateTimeChamp'
      date_value(champ, '%d/%m/%Y %H:%M')
    when 'DateChamp'
      date_value(champ, '%d/%m/%Y')
    when 'CheckboxChamp'
      champ.value
    when 'NumeroDnChamp'
      "#{champ.numero_dn}|#{champ.date_de_naissance}"
    when 'DossierLinkChamp', 'SiretChamp'
      champ.string_value
    when 'PieceJustificativeChamp'
      champ&.file&.filename
    else
      puts champ.__typename
    end
  end

  def date_value(champ, format)
    if champ.value.present?
      Date.iso8601(champ.value).strftime(format)
    else
      add_message(Message::WARN, "champ #{champ.label} vide")
      ''
    end
  end

  def compute_dynamic_fields
    @computed = compute_cells if @calculs.present?
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
