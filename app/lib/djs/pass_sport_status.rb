# frozen_string_literal: true

module Djs
  class PassSportStatus < DossierTask
    def initialize(job, params)
      super
      @champ_status = params['champ_status'] || 'Statut robot'
      @champ_siret = params['champ_siret'] || 'Numéro Tahiti iti'
      @champ_eligible = params['champ_eligible'] || 'Structure éligible'
      @champ_factures = params['champ_factures'] || 'Factures valides'
      @champ_cps_feedback = params['champ_retours_cps'] || 'Retours CPS'
      @cps_feedback_dir = params['rep_retours_cps']
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
      siret = field_value(@champ_siret)&.value.presence || @dossier.demandeur.siret
      siret = (@dossier.demandeur.siret + siret) if siret.length < 7
      siret = siret.gsub(/[^A-Z0-9]+/i, '')[0..9]
      data = PassSportData.create_or_find_by(dossier: @dossier.number) do |data|
        data.siret = siret
      end
      data.siret = siret
      data.status = field_value(@champ_status)&.value
      data.eligible = field_value(@champ_eligible)&.value
      data.invoices_verified = field_value(@champ_factures)&.value
      data.save!
    end

    def after_run
      immatriculations.each do |immatriculation|
        PassSportData.where(siret: immatriculation[:siret].gsub(/[^A-Z0-9]+/i, '')).each do |data|
          @dossier = nil
          handle_cps_feedback(data)
          new_status = compute_status(data, immatriculation)
          next if data.status == new_status

          SetAnnotationValue.set_value(md_dossier(data), instructeur, @champ_status, new_status)
          data.status = new_status
          data.save!
        end
      end
    end

    def handle_cps_feedback(data)
      # cps_feedback_path = "#{@params[:rep_retours_cps]}/#{data.dossier}.csv"
      cps_feedback_path = "#{@params[:rep_retours_cps]}/424862.csv"
      return unless File.exist?(cps_feedback_path)

      checksum = FileUpload.checksum(cps_feedback_path)
      return if data.cps_feedback_checksum == checksum

      SetAnnotationValue.set_piece_justificative(md_dossier(data), instructeur, @champ_cps_feedback, cps_feedback_path)
      data.cps_feedback_checksum = checksum
      data.save!
    end

    def md_dossier(data)
      @dossier ||= DossierActions.on_dossier(data.dossier)
    end

    def compute_status(data, immatriculation)
      if immatriculation[:status] == 'OK'
        SetAnnotationValue.set_value(md_dossier(data), instructeur, @champ_eligible, true) unless data.eligible
        if !data.invoices_verified
          'DJS En attente vérification des factures'
        elsif data.cps_feedback_checksum.blank?
          'CPS En attente inscriptions'
        else
          'CPS Traité'
        end
      elsif immatriculation[:status] == 'KO'
        'CPS Immatriculation bloquée'
      elsif data.eligible
        'CPS En attente immatriculation'
      else
        'DJS En attente vérification éligibilité'
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

    def instructeur
      @instructeur ||= DemarcheActions.instructeur_id(@demarche_id, @params[:instructeur])
    end
  end
end

