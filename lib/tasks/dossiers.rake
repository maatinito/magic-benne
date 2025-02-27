# frozen_string_literal: true

namespace :dossiers do
  desc 'close dossiers where arrival date is after June 23'
  task close_obsolete: :environment do
    include Utils
    since = 2.days.ago
    demarche = 1155
    close_date = Date.new(2021, 0o6, 23)
    DossierActions.on_dossiers(demarche, since) do |dossier|
      if %w[en_construction en_instruction].include?(dossier.state)
        date = Date.iso8601(dossier_value(dossier, "Date d'arrivée").value)
        if date > close_date
          puts "#{dossier.number} = #{Date.iso8601(dossier_value(dossier, "Date d'arrivée").value)}"
        elsif date.year < 2021
          puts "#{dossier.number} XXXXXX #{Date.iso8601(dossier_value(dossier, "Date d'arrivée").value)}"
        else
          puts "#{dossier.number} X #{Date.iso8601(dossier_value(dossier, "Date d'arrivée").value)}"
        end
      end
    end
  end
end
