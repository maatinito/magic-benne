# frozen_string_literal: true

def msg_present(dossier_with_messages)
  dossier_with_messages.messages&.any? { |msg| msg.body.include?(MESSAGE_MARKER) }
end

ENTERPRISE_MESSAGE = <<~MSG.freeze
  Bonjour,

  Vous avez complété un dossier concernant l'obligation vaccinale.

  Ce dossier est traité et les certificats de conformité sont maintenant disponibles pour chaque salarié dont la conformité <u>est connue</u>.

  Pouvez-vous demander aux salariés que vous avez déclarés d'aller sur leur espace Tatou https://tatou.cps.pf#{' '}
  pour que chacun vérifie s'il a bien reçu son document de conformité ?

  Attention: si le document n'est pas disponible, cela signifie juste que sa situation vis à vis de la conformité n'est <b>pas connu</b>.#{' '}
  Chaque salarié doit alors déclarer sa situation dans les 15 jours en allant sur la page http://www .

  Cordialement.
  La plateforme Oblivacc.
MSG

MESSAGE_MARKER = 'reçu son document de conformité'

namespace :dossiers do
  desc 'close dossiers where arrival date is after June 23'
  task info_particulier: :environment do
    include Utils
    since = 2.days.ago
    demarches = [1333, 1334]
    since = 2.months.ago
    demarches.each do |demarche_id|
      gql_instructeur = instructeur(demarche_id, 'magic.benne@informatique.gov.pf')

      DossierActions.on_query(MesDemarches::Queries::DossierInfos, demarche_id, since: since, state: 'accepte') do |dossier|
        puts "Processing #{dossier.number} on demarche #{demarche_id}"
        DossierActions.on_dossier(dossier.number, query: MesDemarches::Queries::DossierMessages) do |dossier_with_messages|
          unless msg_present(dossier_with_messages)
            send_enterprise_message(dossier, gql_instructeur.id, ENTERPRISE_MESSAGE)
            puts '  message sent.'
          end
        end
      end
    end
  end

  def send_enterprise_message(dossier, instructeur_id, message)
    # result = MesDemarches::Client.query(MesDemarches::Mutation::EnvoyerMessage,
    #                                     variables: {
    #                                       dossierId: dossier.id,
    #                                       instructeurId: instructeur_id,
    #                                       body: message,
    #                                       clientMutationId: 'dededed'
    #                                     })
    # puts(result.errors.map(&:message).join(',')) if result.errors&.present?
  end

  def instructeur(demarche_id, instructeur_email)
    gql_demarche = DemarcheActions.get_graphql_demarche(demarche_id)
    gql_demarche.groupe_instructeurs.flat_map(&:instructeurs).find { |i| i.email == instructeur_email } ||
      throw(StandardError.new("Aucun instructeur #{instructeur_email} sur la demarche #{demarche_id}"))
  end
end
