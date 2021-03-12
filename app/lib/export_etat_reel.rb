# frozen_string_literal: true

class ExportEtatReel < ExportEtatNominatif
  include Utils

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
    index = report_index(@initial_dossier, @month)
    "#{dir}/#{basename} Mois #{index} - #{dossier_nb} - #{@year}-#{@month}.csv"
  end

end
