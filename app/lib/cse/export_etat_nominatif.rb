# frozen_string_literal: true

# service to download dossier report and save them in common format

require 'tempfile'
require 'open-uri'
require 'roo'
require 'fileutils'

module Cse
  class ExportEtatNominatif < ExportExcel
    def version
      super + 1
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
      line[:aide] = line[:aide].round if line[:aide].is_a?(Float)
      line[:aide_maximale] = 0
      line[:dn] = line[dn].round if line[:dn].is_a?(Float)
      line[:dn] = '%07d' % line[dn] if line[:dn].is_a?(String)
      line
    end
  end
end
