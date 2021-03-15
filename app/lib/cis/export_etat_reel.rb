# frozen_string_literal: true
module Cis
  class ExportEtatReel < ExportEtatPrevisionnel
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

    def output_path(_sheet_name)
      dossier_nb = dossier.number
      dir = create_target_dir(initial_dossier)
      basename = params[:prefixe_fichier] || params[:champ_etat] || 'Reel'
      index = report_index(@initial_dossier, @month)
      "#{dir}/#{basename}_Mois_#{index} - #{dossier_nb} - #{@year}-#{@month}.csv"
    end
  end
end
