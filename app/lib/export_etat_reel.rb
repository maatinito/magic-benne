# frozen_string_literal: true

class ExportEtatReel < ExportEtatNominatif
  def version
    super + 1
  end

  def required_fields
    super + %i[champ_mois champ_dossier]
  end

  def run
    month_field = param_value(:champ_mois)
    return if month_field.nil?

    @year = month_field.primary_value
    @month = month_field.secondary_value

    @initial_dossier = nil

    super
  end

  private

  def initial_dossier
    if @initial_dossier.nil?
      initial_dossier_field = param_value(:champ_dossier)
      if initial_dossier_field.nil?
        throw "Impossible de trouver le dossier prévisionnel via le champ #{params[:champ_dossier]}"
      end

      @initial_dossier = initial_dossier_field.dossier
    end
    @initial_dossier
  end

  def sheet_regexp
    /Etat|default/
  end

  def output_path(_sheet_name)
    dossier_nb = dossier.number
    dir = self.class.create_target_dir(self, initial_dossier)
    basename = params[:prefixe_fichier] || params[:champ_etat] || 'Etat'
    "#{dir}/#{basename} - Mois #{report_index(@initial_dossier, @month)} - #{dossier_nb} - #{@year}-#{@month}.csv"
  end

  MONTHS = %w[zero janvier février mars avril mai juin juillet août septembre octobre novembre décembre].freeze

  def report_index(dossier, month)
    # DIESE initial
    start_month = self.class.dossier_field_value(dossier, 'Mois 1')&.value&.downcase
    start_month = self.class.dossier_field_value(dossier, 'Mois M')&.value&.downcase if start_month.nil?
    if start_month.nil?
      # CSE initial
      start_month = self.class.dossier_field_value(dossier, 'Date de démarrage de la mesure (Mois 1)')&.value
      start_month = Date.parse(start_month).month if start_month.present?
    end
    if start_month.nil?
      # Avenant
      mois_2 = self.class.dossier_field_value(dossier, 'Nombre de salariés DiESE au mois 2')
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
