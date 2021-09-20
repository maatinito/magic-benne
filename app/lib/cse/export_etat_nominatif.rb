# frozen_string_literal: true

# service to download dossier report and save them in common format

require 'tempfile'
require 'open-uri'
require 'roo'
require 'fileutils'

module Cse
  class ExportEtatNominatif < ExportExcel
    def version
      super + 4
    end

    private

    TITLE_LABELS = [
      'Nom de famille', 'Nom marital', 'Prénom', 'Date de naissance', 'DN', 'Heures avant ',
      'Brut mensuel moyen', 'Heures à réaliser', 'DMO', "Jours non rémunérés|Jours d'absence",
      "Jours d'indemnités journalières", 'Taux RTT*', 'Aide', 'Cotisations', '% temps présent',
      '% réalisé convention|% convention effectuée', '% perte salaire', '% aide', 'plafond'
    ].freeze

    def title_labels
      TITLE_LABELS
    end

    def normalize_line(line)
      normalize_int(:aide, line)
      normalize_int(:dn, line)
      line[:aide_maximale] = 0
      line
    end
  end
end
