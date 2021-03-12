module Utils
  def dossier_field_value(dossier, field)
    return nil if dossier.nil? || field.blank?

    objects = [*dossier]
    field.split(/\./).each do |name|
      objects = objects.flat_map { |object| object.champs.select { |champ| champ.label == name } }
      Rails.logger.warn("Sur le dossier #{dossier.number}, le champ #{field} est vide.") if objects.blank?
    end
    objects&.first
  end

  MONTHS = %w[zero janvier février mars avril mai juin juillet août septembre octobre novembre décembre].freeze

  def report_index(dossier, month)
    # DIESE initial
    start_month = dossier_field_value(dossier, 'Mois 1')&.value&.downcase
    start_month = dossier_field_value(dossier, 'Mois M')&.value&.downcase if start_month.nil?
    if start_month.nil?
      # CSE initial
      start_month = dossier_field_value(dossier, 'Date de démarrage de la mesure (Mois 1)')&.value
      start_month = Date.parse(start_month).month if start_month.present?
    end
    if start_month.nil?
      # Avenant
      mois_2 = dossier_field_value(dossier, 'Nombre de salariés DiESE au mois 2')
      if mois_2.present?
        start_month = mois_2.value.blank? ? 11 : 12
      end
    end
    if start_month.nil?
      throw "Le dossier initial #{dossier.number} n'a pas de champ permettant de connaitre le mois de démarrage de la mesure. (champ mois_1?)"
    end

    start_month = MONTHS.index(start_month) if start_month.is_a?(String)
    current_month = MONTHS.index(month.downcase)
    throw "Impossible de reconnaitre les mois de démarrage (#{start_month})" if start_month.nil?

    throw "Impossible de reconnaitre les mois de l'etat en cours (#{month})" if current_month.nil?

    current_month += 12 if current_month < start_month
    current_month - start_month + 1
  end
end