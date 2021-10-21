# frozen_string_literal: true

module Sante
  class ExportOblivacc < ExportExcel
    def version
      super + 4
    end

    TITLE_LABELS = [
      'Civilité', 'Nom', 'Prénom', 'Nom marital', 'DN', 'Date de naissance', 'Téléphone', 'Activité'
    ].freeze

    def title_labels
      TITLE_LABELS
    end

    private

    def sheet_regexp
      /Liste.*/
    end

    def output_path(_sheet_name)
      dossier_nb = dossier.number
      dir = output_dir
      FileUtils.mkpath(dir)
      basename = params[:prefixe_fichier] || params[:champ_etat] || 'oblivacc-excel'
      "#{dir}/#{basename} - #{dossier_nb}.csv"
    end

    def normalize_line(line)
      # insert dossier number in front of all attributes
      old = line.dup
      line.clear
      line[:ID] = dossier.number
      line.merge!(old)
      super
    end
  end
end
