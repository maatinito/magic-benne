# frozen_string_literal: true

class DemarcheActions
  EPOCH = Time.zone.parse('2000-01-01 00:00')

  def self.instructeur_id(demarche_number, instructeur_email)
    result = MesDemarches::Client.query(MesDemarches::Queries::Instructeurs,
                                        variables: { demarche: demarche_number })
    throw StandardError.new result.errors.messages.values.map { |m| m.join(',') }.join(',') if result.errors.present?
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

  def self.get_demarche(demarche_number, configuration_name)
    gql_demarche = get_graphql_demarche(demarche_number)
    demarche = update_or_create_demarche(gql_demarche, configuration_name)
    update_instructeurs(demarche, gql_demarche)
    demarche
  end

  def self.get_graphql_demarche(demarche_number)
    result = MesDemarches::Client.query(MesDemarches::Queries::Demarche,
                                        variables: { demarche: demarche_number })
    throw StandardError.new result.errors.messages.values.map { |m| m.join(',') }.join(',') if result.errors.present?
    throw StandardError.new "La démarche #{demarche_number} n'existe pas" if result&.data&.demarche.nil?

    result.data.demarche
  end

  def self.update_or_create_demarche(gql_demarche, configuration_name)
    demarche = Demarche.find_or_create_by({ id: gql_demarche.number }) do |d|
      d.queried_at = EPOCH
    end
    demarche.update(name: configuration_name)
    demarche
  end

  def self.update_instructeurs(demarche, gql_demarche)
    instructeurs = User
                   .where(email: gql_demarche.groupe_instructeurs.flat_map(&:instructeurs).map(&:email))
                   .or(User.where(is_admin: true))
    demarche.instructeurs = instructeurs
  end
end
