# frozen_string_literal: true

class DemarcheActions
  EPOCH = Time.zone.parse('2000-01-01 00:00')

  def self.instructeur_id(demarche_number, instructeur_email)
    result = MesDemarches::Client.query(MesDemarches::Queries::Instructeurs,
                                        variables: { demarche: demarche_number })
    throw StandardError.new result.errors.join(',') if result.errors.present?
    throw StandardError.new "La démarche #{demarche_number} n'existe pas" if result.data.demarche.nil?

    gql_demarche = result.data.demarche
    gql_instructeur = gql_demarche.groupe_instructeurs.flat_map(&:instructeurs).find do |i|
      i.email == instructeur_email
    end
    if gql_instructeur.nil?
      throw StandardError.new "Aucun instructeur #{@instructeur.email} sur la demarche #{demarche_number}"
    end

    gql_instructeur.id
  end

  def self.title(demarche_number)
    result = MesDemarches::Client.query(MesDemarches::Queries::Demarche,
                                        variables: { demarche: demarche_number })
    throw StandardError.new result.errors.join(',') if result.errors.present?
    throw StandardError.new "La démarche #{demarche_number} n'existe pas" if result.data.demarche.nil?

    result.data.demarche.title
  end
end
