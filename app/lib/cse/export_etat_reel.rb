# frozen_string_literal: true

module Cse
  class ExportEtatReel < ExportEtatNominatif
    include Utils

    def version
      super + 3
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

    def sheet_regexp
      /Etat|default|Mois/
    end

    def output_path(_sheet_name)
      dossier_nb = dossier.number
      dir = create_target_dir(initial_dossier)
      basename = params[:prefixe_fichier] || params[:champ_etat] || 'Etat'
      index = report_index(@initial_dossier, @month)
      "#{dir}/#{basename}_Mois_#{index} - #{dossier_nb} - #{@year}-#{@month}.csv"
    end

    def sheet_ok?(sheet_name, employees)
      index = report_index(initial_dossier, @month)
      unless (ok = (1..max_months).include?(index))
        add_message(Message::ERROR, "Il n'est pas possible de déclarer un mois #{index}, le maximum est #{max_months}.")
      end
      super && ok
    end

    def max_months
      6
    end
  end
end
