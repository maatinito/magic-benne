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

    def report_index(dossier, month)
      file = dossier.annotations.select { |champ| champ.label == 'Candidats admis' }&.first&.file
      throw "Le dossier initial #{dossier.number} n'a pas de list de candidats admis" if file.nil?
      download(file.url, file.filename) do |f|
        xlsx = Roo::Spreadsheet.open(f, csv_options: { col_sep: ';', encoding: Encoding::UTF_8 })
        sheet = xlsx.sheet(0)
        start_date = Date.parse(sheet.cell(2, 2))
        start_month = start_date.month
        if start_month.nil?
          throw "Le dossier initial #{dossier.number} n'a pas de champ permettant de connaitre le mois de démarrage de la mesure. (champ mois_1?)"
        end
        current_month = MONTHS.index(month.downcase)
        throw "Impossible de reconnaitre les mois de démarrage (#{start_month})" if start_month.nil?

        throw "Impossible de reconnaitre les mois de l'etat en cours (#{month})" if current_month.nil?

        current_month += 12 if current_month < start_month
        current_month - start_month + 1
      end
    end
  end
end
