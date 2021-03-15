# frozen_string_literal: true
module Cse
  class ExportEtatPrevisionnel < ExportEtatNominatif
    def version
      super + 1
    end

    private

    def sheet_regexp
      /Mois ([0-9])/
    end

    def output_path(sheet_name)
      match = sheet_name.match(sheet_regexp)
      report_index = match[1]

      dossier_nb = dossier.number
      dir = create_target_dir(dossier)
      basename = params[:prefixe_fichier] || params[:champ_etat] || 'Etat'
      "#{dir}/#{basename}_Mois_#{report_index} - #{dossier_nb}.csv"
    end
  end
end