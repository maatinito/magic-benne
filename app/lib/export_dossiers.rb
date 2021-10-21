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
    super + %i[calculs prefixe_fichier]
  end

  def run
    compute_dynamic_fields
    line = get_fields(params[:champs])
    save_csv(line)
  end

  def before_run
    @csv = nil
    @calculs.each(&:before_run)
  end

  def after_run
    @calculs.each(&:after_run)
    @csv&.close
  end

  def version
    super + 1
  end

  private

  def csv
    if @csv.nil?
      FileUtils.mkpath(output_dir)
      @csv = CSV.open(output_path, 'wb', headers: column_names, write_headers: true, col_sep: ';')
    end
    @csv
  end

  def save_csv(line)
    csv << normalize_line_for_csv(line)
    @csv.flush
    Rails.logger.info("Dossiers sauveardés dans #{output_path}.")
  end

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
    prefixe = @params[:prefixe_fichier] || @demarche_dir
    "#{output_dir}/#{prefixe}-#{demarche_id}-#{Time.zone.now.strftime('%Y-%m-%d-%Hh%M')}.csv"
  end

  def normalize_line_for_csv(line)
    line.map do |cells|
      cells = Array(cells)
      cells.map! { |v| v.is_a?(Date) ? v.strftime('%d/%m/%Y') : v }
      cells.join('|').strip.tr(';', '/')
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
    field, par_defaut = definition(param)
    return par_defaut unless field

    value = @computed[field] if @computed.is_a? Hash
    return value if value.present?

    champs = field_values(field, log_empty: false)
    return champs_to_values(champs) if champs.present?

    values = dossier_values(field)
    return values if values.present?

    add_message(Message::WARN, "Impossible de trouver le champ #{field}")
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

  def champs_to_values(champs)
    champs.map(&method(:champ_value)).compact.select(&:present?)
  end

  def dossier_values(field)
    path = MD_FIELDS[field]
    return if path.nil?

    path.split(/\./).reduce(@dossier) do |o, f|
      case o
      when GraphQL::Client::List, Array
        o.map { |elt| elt.send(f) }
      else
        [o.send(f)] if o.present?
      end
    end
  end

  def champ_value(champ)
    return nil unless champ

    return champ unless champ.respond_to?(:__typename) # direct value

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
