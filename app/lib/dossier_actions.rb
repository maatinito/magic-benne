# frozen_string_literal: true

class DossierActions
  EPOCH = Time.zone.parse('2000-01-01 00:00')

  def self.on_dossiers(demarche_id, since, &block)
    on_query(MesDemarches::Queries::DossiersModifies, demarche_id, since: since) do |dossier|
      block.call dossier
    end
  end

  def self.on_dossier(dossier_number, query: MesDemarches::Client::Dossier)
    result = MesDemarches::Client.query(query, variables: { number: dossier_number })
    dossier = result.data&.dossier
    yield dossier if dossier.present?
    Rails.logger.error(result.errors.values.join(',')) unless dossier
  end

  def self.on_query(query, demarche_id, since: nil, state: nil)
    cursor = nil
    loop do
      GC.compact
      response = MesDemarches::Client.query(query,
                                            variables: {
                                              demarche: demarche_id,
                                              since: since.iso8601,
                                              state: state,
                                              cursor: cursor
                                            })

      unless (data = response.data)
        throw StandardError.new "La démarche #{demarche_id} est introuvable #{ENV['GRAPHQL_HOST']}: #{response.errors.values.join(',')}"
      end

      if data&.errors&.values&.present?
        throw StandardError.new "La requete pour recevoir les dossiers de #{demarche_id} comporte des erreurs #{response.errors.values.join(',')}"
      end

      dossiers = data.demarche.dossiers
      dossiers.nodes.each do |dossier|
        yield dossier if dossier.present?
      end
      page_info = dossiers.page_info

      break unless page_info.has_next_page

      cursor = page_info.end_cursor
    end
  end
end
