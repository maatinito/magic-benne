# frozen_string_literal: true

module Res
  class ExportEtatPrevisionnel < ExportExcel
    def version
      super + 2
    end

    TITLE_LABELS = [
      'Nom', 'Prénom', 'Numéro DN', 'Date de naissance', 'Type de contrat', 'Date début',
      'Salaire brut mensuel\s+M-1', 'Salaire brut mensuel\s+M-2', 'Salaire brut mensuel\s+M-3', 'Salaire brut mensuel',
      "Nombre de jours\s+suspendus"
    ].freeze

    def title_labels
      TITLE_LABELS
    end

    # def dossier_has_right_state
    #   super && field_value('Avis SEFI')&.value == 'Favorable'
    # end

    def normalize_line(line)
      normalize_int(:salaire_brut_mensuel_m_1, line)
      normalize_int(:salaire_brut_mensuel_m_2, line)
      normalize_int(:salaire_brut_mensuel_m_3, line)
      normalize_int(:salaire_brut_mensuel, line)
      line
    end

    private

    def sheet_regexp
      /.*/
    end

    def output_path(_sheet_name)
      dossier_nb = dossier.number
      dir = output_dir
      FileUtils.mkpath(dir)
      basename = params[:prefixe_fichier] || params[:champ_etat] || 'RES'
      "#{dir}/#{basename} - #{dossier_nb}.csv"
    end
  end
end
