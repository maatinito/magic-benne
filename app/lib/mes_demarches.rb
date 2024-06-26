# frozen_string_literal: true

require 'graphql/client'
require 'graphql/client/http'

module MesDemarches
  # Configure GraphQL endpoint using the basic HTTP network adapter.
  host = ENV.fetch('GRAPHQL_HOST', 'https://www.mes-demarches.gov.pf')
  graphql_url = "#{host}/api/v2/graphql"
  # puts "url=#{graphql_url}"
  HTTP = GraphQL::Client::HTTP.new(graphql_url) do
    def headers(_context)
      { Authorization: "Bearer #{ENV.fetch('GRAPHQL_BEARER', nil)}" }
    end
  end

  def self.http(host)
    Rails.cache.fetch("#{host} http client") do
      graphql_url = "#{host}/api/v2/graphql"
      GraphQL::Client::HTTP.new(graphql_url) do
        lambda do
          # headers
          { Authorization: "Bearer #{ENV.fetch('GRAPHQL_BEARER', nil)}" }
        end
      end
    end
  end

  # Fetch latest schema on init, this will make a network request
  Schema = GraphQL::Client.load_schema(HTTP)

  # However, it's smart to dump this to a JSON file and load from disk
  #
  # Run it from a script or rake task
  #   GraphQL::Client.dump_schema(SWAPI::HTTP, "path/to/schema.json")
  #
  # Schema = GraphQL::Client.load_schema("path/to/schema.json")

  Client = GraphQL::Client.new(schema: Schema, execute: HTTP)

  def self.query(definition, variables: {}, context: {})
    max_retries = 10
    retry_count = 0
    success = false

    until success
      begin
        result = Client.query(definition, variables:, context:)
        success = true
      rescue StandardError => e
        retry_count += 1
        raise e if retry_count >= max_retries

        Rails.logger.warn("Attempt #{retry_count} failed querying Mes-Démarches: #{e.message}. Retrying in 1 second...")
        sleep 1
      end
    end
    result
  end

  # list dossiers

  Queries = Client.parse <<-GRAPHQL
    query Demarche($demarche: Int!) {
      demarche(number: $demarche) {
        number
        title
        groupeInstructeurs {
          instructeurs {
            id
            email
          }
        }
      }
    }

    query Instructeurs($demarche: Int!) {
      demarche(number: $demarche) {
        groupeInstructeurs {
          instructeurs {
            id
            email
          }
        }
      }
    }

    query DossierId($number: Int!) {
      dossier(number: $number) {
        id
      }
    }

    query DossierMessages($number: Int!) {
      dossier(number: $number) {
        id
        messages {
          createdAt
          body
        }
      }
    }

    fragment ChampInfo on Champ {
      label
      ... on TextChamp {
          value
      }
      ... on CheckboxChamp {
          value
      }
      ... on IntegerNumberChamp {
          value
      }
      ... on DecimalNumberChamp  {
          value
      }
      ... on DateChamp  {
          value
      }
      ... on LinkedDropDownListChamp {
          primaryValue
          secondaryValue
      }
      ... on PieceJustificativeChamp  {
          files {
              contentType
              byteSize
              filename
              url
              checksum
          }
          stringValue
      }
      ... on NumeroDnChamp  {
          dateDeNaissance
          numeroDn
      }
      ... on SiretChamp {
          stringValue
          etablissement {
            naf
            libelleNaf
            entreprise {
              nom
              raisonSociale
            }
          }
      }
      ... on CiviliteChamp {
          value
      }
      ... on MultipleDropDownListChamp {
          values
      }
    }

    fragment DossierInfo on Dossier {
      id
      number
      archived

      state
      datePassageEnConstruction
      datePassageEnInstruction
      dateTraitement
      dateDerniereModification
      motivation
      usager {
          email
      }
      demandeur {
          ... on PersonnePhysique {
              civilite
              dateDeNaissance
              nom
              prenom
          }
          ... on PersonneMorale {
              siret
              naf
              libelleNaf
              adresse
              numeroVoie
              typeVoie
              nomVoie
              complementAdresse
              codePostal
              localite
              entreprise {
                siren
                capitalSocial
                numeroTvaIntracommunautaire
                formeJuridique
                formeJuridiqueCode
                nomCommercial
                raisonSociale
                siretSiegeSocial
                codeEffectifEntreprise
                dateCreation
                nom
                prenom
              }
              association {
                rna
                titre
                objet
                dateCreation
                dateDeclaration
                dateDeclaration
              }
          }
      }
      instructeurs {
        id
        email
      }
    }

    query Dossier($number: Int!) {
      dossier(number: $number) {
          ...DossierInfo
          annotations {
            id
            ...ChampInfo
            ... on RepetitionChamp {
                champs {
                    ...ChampInfo
                }
            }
          }
          champs {
            ...ChampInfo
            ... on RepetitionChamp {
                champs {
                    ...ChampInfo
                }
            }
            ... on DossierLinkChamp {
              stringValue
            }
          }
        }
      }

    query DossierInfos($demarche: Int!, $since: ISO8601DateTime!, $state: DossierState, $cursor: String) {
      demarche(number: $demarche) {
        dossiers(updatedSince: $since, state: $state, after: $cursor) {
          pageInfo {
              endCursor
              hasNextPage
          }
          nodes {
            ...DossierInfo
          }
        }
      }
    }

    query DossiersModifies($demarche: Int!, $since: ISO8601DateTime!, $cursor: String) {
      demarche(number: $demarche) {
        dossiers(updatedSince: $since, after: $cursor) {
          pageInfo {
              endCursor
              hasNextPage
          }
          nodes {
            ...DossierInfo
            annotations {
              id
              ...ChampInfo
              ... on RepetitionChamp {
                  champs {
                      ...ChampInfo
                  }
              }
            }
            champs {
              ...ChampInfo
              ... on RepetitionChamp {
                  champs {
                      ...ChampInfo
                  }
              }
              ... on DossierLinkChamp {
                stringValue
              }
            }
          }
        }
      }
    }
  GRAPHQL

  # ... on DossierLinkChamp {
  #   stringValue
  #   dossier {
  #     ...DossierInfo
  #     annotations {
  #       ...ChampInfo
  #     }
  #     champs {
  #       ...ChampInfo
  #       ... on RepetitionChamp {
  #         champs {
  #           ...ChampInfo
  #         }
  #       }
  #     }
  #   }

  Mutation = Client.parse <<-GRAPHQL
    mutation EnvoyerMessage($dossierId: ID!, $instructeurId: ID!, $body: String!, $clientMutationId: String) {
        dossierEnvoyerMessage(
            input: {
                dossierId: $dossierId,
                instructeurId: $instructeurId,
                body: $body
                clientMutationId: $clientMutationId,
            }) {
            clientMutationId
            errors {
                message
            }
        }
    }
  GRAPHQL
end
