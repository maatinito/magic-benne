# frozen_string_literal: true

def msg_present(dossier_with_messages)
  dossier_with_messages.messages&.any? { |msg| msg.body.include?(MESSAGE_MARKER) }
end

ENTERPRISE_MESSAGE = <<~MSG
  Bonjour,

  Vous avez complété le dossier concernant l'obligation vaccinale.

  Ce dossier est traité et les certificats de conformité sont maintenant disponibles pour chaque salarié dont la conformité <u>est connue</u>.

  Vous pouvez prévenir vos salariés qu'ils peuvent aller chercher leur certificat de conformité sur leur espace Tatou https://tatou.cps.pf#{' '}

  Cordialement.
  La plateforme Oblivacc.
MSG

MESSAGE_MARKER = 'reçu son document de conformité'

namespace :dossiers do
  desc 'Send message to enterprise regarding oblivacc'
  task info_particulier: :environment do
    include Utils
    demarches = [1333, 1334]
    since = 6.months.ago
    demarches.each do |demarche_id|
      gql_instructeur = instructeur(demarche_id, 'magic.benne@informatique.gov.pf')

      DossierActions.on_query(MesDemarches::Queries::DossierInfos, demarche_id, since: since, state: 'accepte') do |dossier|
        puts "Processing #{dossier.number} on demarche #{demarche_id}"
        DossierActions.on_dossier(dossier.number, query: MesDemarches::Queries::DossierMessages) do |dossier_with_messages|
          if msg_present(dossier_with_messages)
            puts '  message already sent.'
          else
            send_enterprise_message(dossier, gql_instructeur.id, ENTERPRISE_MESSAGE)
            puts '  message sent.'
          end
        end
      end
    end
  end

  def send_enterprise_message(dossier, instructeur_id, message)
    if dossier.number == 215_286
      result = MesDemarches::Client.query(MesDemarches::Mutation::EnvoyerMessage,
                                          variables: {
                                            dossierId: dossier.id,
                                            instructeurId: instructeur_id,
                                            body: message,
                                            clientMutationId: 'dededed'
                                          })
      puts(result.errors.map(&:message).join(',')) if result.errors&.present?
    end
  end

  def instructeur(demarche_id, instructeur_email)
    gql_demarche = DemarcheActions.get_graphql_demarche(demarche_id)
    gql_demarche.groupe_instructeurs.flat_map(&:instructeurs).find { |i| i.email == instructeur_email } ||
      throw(StandardError.new("Aucun instructeur #{instructeur_email} sur la demarche #{demarche_id}"))
  end
end
