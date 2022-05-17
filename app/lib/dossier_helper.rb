# frozen_string_literal: true

module DossierHelper
  def object_values(field_source, field, log_empty: true)
    objects = [field_source]
    field.split(/\./).each do |name|
      objects = objects.flat_map do |object|
        object = object.dossier if object.respond_to?(:dossier)
        r = []
        r += select_champ(object.champs, name) if object.respond_to?(:champs)
        r += select_champ(object.annotations, name) if object.respond_to?(:annotations)
        r += attributes(object, name) if object.respond_to?(name)
        r += hash_values(name, object) if object.respond_to?(:[])
        r
      end
      Rails.logger.warn("Sur le dossier #{@dossier.number}, le champ #{field} est vide.") if log_empty && objects.blank?
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

  def hash_values(name, object)
    ((v = object[name]).is_a?(Array) ? v : [v])
  end

  def date_value(champ)
    if champ.value.present?
      Date.iso8601(champ.value)
    else
      add_message(Message::WARN, "champ #{champ.label} vide")
      ''
    end
  end
end
