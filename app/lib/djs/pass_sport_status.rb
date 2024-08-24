# frozen_string_literal: true

module Djs
  class PassSportStatus < DossierTask
    def initialize(job, params)
      super
      @champ_status = params['champ_status'] || 'Statut robot'
      @champ_siret = params['champ_siret'] || 'Numéro Tahiti iti'
      @champ_eligible = params['champ_eligible'] || 'Structure éligible'
      @champ_factures = params['champ_factures'] || 'Factures valides'
      @champ_children_feedback = params['champ_retours_cps'] || 'Retours CPS'
      @children_feedback_dir = params['rep_retours_cps']
      @immatriculation_path = params['excel_immatriculations']
    end

    def version
      super + 1
    end

    def required_fields
      super + %i[excel_immatriculations instructeur rep_retours_cps]
    end

    def authorized_fields
      super + %i[champ_status champ_siret champ_eligible champ_factures champ_retours_cps]
    end

    def run
      siret = @dossier.demandeur.siret
      siret = siret.gsub(/[^A-Z0-9]+/i, '')[0..9]
      data = PassSportData.create_or_find_by(dossier: @dossier.number) do |d|
        d.siret = siret
      end
      if @dossier.state == 'accepte'
        data.destroy
        return
      end

      data.siret = siret
      data.status = field_value(@champ_status)&.value
      data.eligible = @dossier.state == 'en_instruction'
      data.status = if @dossier.state == 'en_construction'
                      'DJS Attente passage en instruction'
                    else
                      field_value(@champ_status)&.value
                    end
      SetAnnotationValue.set_value(@dossier, instructeur, @champ_status, data.status)
      data.save!
    end

    def after_run
      immatriculations.each do |immatriculation|
        PassSportData.where(siret: immatriculation[:siret].gsub(/[^A-Z0-9]+/i, '')).each do |data|
          handle_children_feedback(data)
          new_status = compute_status(data, immatriculation)
          next if data.status == new_status

          if refreshed_dossier(data).present?
            SetAnnotationValue.set_value(@dossier, instructeur, @champ_status, new_status)
            data.status = new_status
            data.save!
          else
            data.destroy
          end
        end
      end
    end

    def handle_children_feedback(data)
      cps_feedback_path = "#{@children_feedback_dir}/#{data.dossier}.csv"
      return unless File.exist?(cps_feedback_path)

      checksum = FileUpload.checksum(cps_feedback_path)
      return if data.cps_feedback_checksum == checksum

      SetAnnotationValue.set_piece_justificative(@dossier, instructeur, @champ_children_feedback, cps_feedback_path) if refreshed_dossier(data).present?
      data.cps_feedback_checksum = checksum
      data.save!
    end

    def compute_status(data, immatriculation)
      if !data.eligible
        'DJS Attente passage en instruction'
      elsif immatriculation[:status] == 'OK'
        if data.cps_feedback_checksum.blank?
          'CPS Attente inscriptions'
        else
          'CPS Traité'
        end
      elsif immatriculation[:status] == 'KO'
        'CPS Immatriculation bloquée'
      else
        'CPS Attente immatriculation'
      end
    end

    TITLES = {
      date: 'Date',
      siret: 'Numéro Tahiti Iti',
      status: 'Statut'
    }.freeze

    def immatriculations
      xlsx = Roo::Spreadsheet.open(@immatriculation_path)
      xlsx.parse(TITLES)
    end

    private

    def refreshed_dossier(data)
      @dossier = DossierActions.on_dossier(data.dossier) if @dossier.nil? || @dossier.number != data.dossier
      @dossier
    end

    def instructeur
      @instructeur ||= DemarcheActions.instructeur_id(@demarche_id, @params[:instructeur])
    end
  end
end
