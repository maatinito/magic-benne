# frozen_string_literal: true

module DossierHelper
  def object_values(field_source, field, log_empty: true)
    objects = [field_source]
    field.split('.').each do |name|
      objects = objects.flat_map do |object|
        object = follow_dossier_link(object)
        r = []
        r += select_champ(object.champs, name) if object.respond_to?(:champs)
        r += select_champ(object.annotations, name) if object.respond_to?(:annotations)
        r += attributes(object, name) if object.respond_to?(name)
        r += hash_values(name, object) if object.respond_to?(:[])
        r += simple_attribute(field_source, name)
        r
      end
      Rails.logger.warn("Sur le dossier #{field_source.number}, le champ #{field} est vide.") if log_empty && objects.blank?
    end
    objects
  end

  def attributes(object, name)
    values = Array(object.send(name))
    return values unless name.match?(/date/i)

    values.map { |v| v.is_a?(String) ? Date.iso8601(v) : v }
  end

  def dossier_values(dossier, field, log_empty: true)
    object_values(dossier, field, log_empty:)
  end

  def dossier_value(dossier, field, log_empty: true)
    dossier_values(dossier, field, log_empty:)&.first
  end

  def champ_value(champ)
    return nil unless champ

    return champ unless champ.respond_to?(:__typename) # direct value

    case champ.__typename
    when 'TextChamp', 'CiviliteChamp'
      champ.value || ''
    when 'IntegerNumberChamp'
      champ.value.to_i
    when 'DecimalNumberChamp'
      champ.value.to_f
    when 'MultipleDropDownListChamp'
      champ.values
    when 'LinkedDropDownListChamp'
      "#{champ.primary_value}/#{champ.secondary_value}"
    when 'DateTimeChamp', 'DateChamp'
      date_value(champ)
    when 'CheckboxChamp'
      champ.value
    when 'NumeroDnChamp'
      "#{champ.numero_dn}|#{champ.date_de_naissance}"
    when 'DossierLinkChamp', 'SiretChamp'
      champ.string_value
    when 'PieceJustificativeChamp'
      champ&.file&.filename
    else
      throw ExportError.new("Unknown field type #{champ.label}:#{champ.__typename}")
    end
  end

  def select_champ(champs, name)
    champs.select { |champ| champ.label == name }
  end

  private

  def follow_dossier_link(object)
    object = object.dossier if object.respond_to?(:dossier)
    object = get_dossier(object.string_value) if object.respond_to?(:__typename) && object.__typename == 'DossierLinkChamp'
    object
  end

  def get_dossier(number)
    @dossiers ||= {}
    (@dossiers[number] ||= DossierActions.on_dossier(number))
  end

  def hash_values(name, object)
    v = object[name]
    return [] unless v

    v.is_a?(Array) ? v : [v]
  end

  def date_value(champ)
    if champ.value.present?
      Date.iso8601(champ.value)
    else
      #   add_message(Message::WARN, "champ #{champ.label} vide")
      ''
    end
  end

  def get_field_values(field, par_defaut)
    return [par_defaut] unless field

    champs = field_values(field, log_empty: false)
    return champs_to_values(champs) if champs.present?

    add_message(Message::WARN, "Impossible de trouver le champ #{field}") unless par_defaut
    par_defaut
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

  def simple_attribute(source, field)
    path = MD_FIELDS[field]
    return [] if path.nil?

    r = path.split('.').reduce(source) do |o, f|
      case o
      when GraphQL::Client::List, Array
        o.map { |elt| elt.send(f) }
      else
        [o.send(f)] if o.present?
      end
    end
    path.starts_with?('date') ? r.map! { |s| DateTime.iso8601(s) } : r
  end

  def champs_to_values(champs)
    champs.map(&method(:champ_value)).compact.select(&:present?)
  end

  #----- repetition helpers

  def for_each_repetition(param)
    blocks = param_blocks(param)
    return blocks unless block_given?

    dossier_source = @dossier
    begin
      blocks.each do |block|
        @dossier = FieldSource.new(dossier_source, {}, block)
        yield
      end
    ensure
      @dossier = dossier_source
    end
  end

  def param_blocks(param)
    field_blocks(@params[param])
  end

  def field_blocks(field_name)
    repetition = field_value(field_name) || annotation_value(field_name)
    return nil unless repetition && repetition.__typename == 'RepetitionChamp' && repetition.champs.present?

    blocks_from(repetition)
  end

  def blocks_from(repetition_champ)
    repetition_champ.champs.each_with_object([]) do |champ, result|
      block = result.last
      result << (block = Block.new) if block.nil? || block.champs&.first&.label == champ.label # next line/hash
      block.add(champ)
    end
  end

  class Block
    attr_accessor :champs

    def initialize
      @champs = []
    end

    def add(champ)
      @champs << champ
    end
  end
end
