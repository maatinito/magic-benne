# frozen_string_literal: true

module Cse
  class ExportEtatReel < ExportEtatNominatif
    include Utils

    def initialize(job, params)
      super
      load_res_people
    end

    def version
      super + 5
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

    RES_MAX_DAYS = 28
    # RES_MONTH = 'Aout'
    RES_MONTH = 'Septembre'

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

    def sheet_ok?(sheet_name, rows)
      index = report_index(initial_dossier, @month)
      unless (ok = (1..max_months).include?(index))
        add_message(Message::ERROR, "Il n'est pas possible de déclarer un mois #{index}, le maximum est #{max_months}.")
      end
      super && ok
    end

    def max_months
      6
    end

    def normalize_line(line)
      super
      if @month == RES_MONTH || Rails.env.development?
        res_suspended_days = @res_people[line[:dn]]
        if res_suspended_days.present?
          dse_suspended_days = normalized_suspended(line[:jours_non_remuneres_jours_d_absence])
          line[:jours_non_remuneres_jours_d_absence] = 100 + [res_suspended_days, dse_suspended_days].max
        end
      end
      line
    end

    def normalized_suspended(suspended)
      to_i(suspended).clamp(0, RES_MAX_DAYS)
    end

    def load_res_people
      dir = 'storage/RES'
      csvs = Dir.glob("#{dir}/*.csv")
      @res_people = {}
      csvs.each do |f|
        CSV.foreach(f, col_sep: ';', headers: true, header_converters: :symbol) do |line|
          @res_people[line[:numero_dn]] = normalized_suspended(line[:nombre_de_jours_suspendus])
        end
      end
    end
  end
end
