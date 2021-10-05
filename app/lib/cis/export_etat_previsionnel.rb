# frozen_string_literal: true

module Cis
  class ExportEtatPrevisionnel < ExportExcel
    def version
      super + 2
    end

    private

    TITLE_LABELS = [
      'Nom de famille', 'Prénom', 'Date de naissance', 'DN', 'Civilité', "Niveau d'étude",
      'Date de naissance du', 'DN du conjoint', "Nb d'enfants", 'Activité',
      'Code ROME', "Jours d'absences", 'Aide'
    ].freeze

    def title_labels
      TITLE_LABELS
    end

    def sheet_regexp
      /^((?!Menus|Feui).)*$/
    end

    def output_path(_sheet_name)
      dir = create_target_dir(dossier)
      basename = params[:prefixe_fichier] || params[:champ_etat] || 'Etat'
      "#{dir}/#{basename} - #{dossier.number}.csv"
    end

    CODES_ROMES = {
      'Accueil et d’information' => 'M1601',
      'Aide agricole et horticole' => 'A1402',
      'Aide-livreur' => 'N4105',
      'Animation culturelles et sportives' => 'G1202',
      'Assistance auprès de personnes' => 'K1302',
      'Assistant de vie scolaire' => 'K2104',
      'Autres' => '',
      'Bâtiments (Maintenance)' => 'I1203',
      'Cuisine' => 'G1602',
      'Enquêteur' => 'M1401',
      'Espaces verts et jardins' => 'A1203',
      'Habillement (confection)' => 'B1803',
      'Menuisier' => 'H2206',
      'Mécanicien' => 'I1604',
      'Médiation et proximité' => 'K1204',
      'Propreté des locaux' => 'K2204',
      'Propreté urbaine' => 'K2303',
      'Secrétariat et administration' => 'M1602'
    }.freeze

    def normalize_line(line)
      super
      line[:code_rome] = CODES_ROMES[line[:activite]] || 'Inconnu' if line[:code_rome] == '#NAME?'
      line[:dn] = line[dn].round if line[:dn].is_a?(Float)
      # line[:dn] = format('%07d', line[:dn]) if line[:dn].is_a?(Integer)
      line
    end
  end
end
