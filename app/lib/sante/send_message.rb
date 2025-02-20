# frozen_string_literal: true

module Sante
  class SendMessage < DossierTask
    def version
      super + 8
    end

    COLUMNS = [
      'Nom', 'Nom de naissance', 'Nom normalisé', 'Prénom', 'Date de naissance', 'N° DN', 'Téléphone', 'Email',
      'Statut de la vérification', "Date de la 1ère tentative d'appel", 'Date du 1er contact effectif'
    ].freeze

    STATUT_VERIFICATION = [
      'À contrôler',
      'Contrôlé automatiquement',
      'Contrôlé manuellement',
      'Injoignable',
      'Abandon',
      'Rdv de contrôle pris',
      'Demande de justification effectuée',
      'Convoqué',
      'Personne plus déclarée',
      'Verbalisé',
      'Pas concerné',
      'Ligne à supprimer'
    ].freeze

    SMS = 'Bonjour {}. Etant concerné par l’obligation vaccinale, merci de justifier de votre situation sur https://www.service-public.pf/arass/di'
    MAIL = <<~MAIL.freeze
      Bonjour {},
      Votre employeur vous a déclaré comme personne concernée par la vaccination obligatoire contre la covid-19 et nous n’avons aucune information sur votre situation vaccinale.
      Pour justifier de votre situation vis à vis de l'obligation vaccinale, cliquez sur https://www.service-public.pf/arass/di
      Cordialement,#{' '}
      Les contrôleurs de l'Agence de Régulation de l'Action Sanitaire et Sociale (ARASS) et de la Direction de la santé
    MAIL

    SHEET_NAME = 'Personnes à conformité inconnue'

    def required_fields
      super + %i[conformites_inconnues]
    end

    def run; end

    def after_run
      process_people(params[:conformites_inconnues])
    end

    def process_people(excel_path)
      xlsx = Roo::Excelx.new(excel_path)
      input_sheet = xlsx.sheet(SHEET_NAME)
      output_xlsx, output_sheet = new_xlsx
      @sms_sender = Sante::SmsSender.new

      count = 0
      input_sheet.each(title_regexps) do |person|
        process_person(output_sheet, person)
        count += 1
      end
      xlsx.close

      add_statut_verification(count, output_sheet)
      define_table(output_sheet, count)
      output_xlsx.serialize(excel_path)
    end

    private

    def send_message(person)
      success = false
      tel = person[:telephone] = normalize(person[:telephone])
      if tel.present? && mobile?(tel)
        # puts "Sending SMS to #{tel}"
        msg = SMS.gsub('{}', person_name(person))
        puts msg
        @sms_sender.send_sms(tel, msg)
        success = true
      end
      mail = person[:email]
      if mail.present?
        puts "Sending mail to #{mail}"
        msg = MAIL.gsub('{}', person_name(person))
        puts msg
        NotificationMailer.send_mail(mail, 'Obligation vaccinale', msg).deliver_now
        success = true
      end
      if tel.blank? && mail.blank?
        # puts "Unable to join #{person[:nom_normalise]} #{person[:prenom]}"
      end
      success
    end

    def save_row(output_sheet, person)
      output_sheet.add_row titles.map { |key| person[key] }, style: @styles
    end

    def process_person(output_sheet, person)
      @sent = 0 if person[:nom_normalise] == 'Nom normalisé'
      return if person[:nom_normalise] == 'Nom normalisé' || person[:nom_normalise].blank?

      if @sent < 1000 && person[:date_de_la_1ere_tentative_d_appel].blank? && send_message(person)
        @sent += 1
        person[:date_de_la_1ere_tentative_d_appel] = Time.zone.now
        person[:statut_de_la_verification] = STATUT_VERIFICATION[6]
      end
      save_row(output_sheet, person)
    end

    def person_name(person)
      name = person[:prenom]&.gsub(/[ ,].*/, '')&.gsub(/\b([a-z])/, &:upcase) || '' # remove trailing first names & upcase each word (Jean-Marie)
      family_name = person[:nom_de_naissance]&.sub(/ ([eéÉ]p\.?|[éeÉ]pouse) .*/i, '')&.upcase || ''

      if family_name.present? && name.length + family_name.length + SMS.length - 1 <= 157
        name += ' ' if name.length.positive?
        name += family_name
      end
      name
    end

    def new_xlsx
      output_xlsx = Axlsx::Package.new
      output_sheet = output_xlsx.workbook.add_worksheet(name: SHEET_NAME)
      create_styles(output_xlsx)
      output_header(output_xlsx.workbook, output_sheet)
      [output_xlsx, output_sheet]
    end

    def open_xlsx(excel_path)
      xlsx = Roo::Excelx.new(excel_path)
      xlsx.sheet(SHEET_NAME)
    end

    def define_table(output_sheet, count)
      output_sheet.add_table "A1:K#{count}", name: 'Inconnues', style_info: { name: 'TableStyleMedium2', show_row_stripes: true }
    end

    def create_styles(output_xlsx)
      s = output_xlsx.workbook.styles
      s_standard = s.add_style num_fmt: 1
      s_date = s.add_style num_fmt: 14
      s_date_time = s.add_style num_fmt: 22
      @styles = [s_standard, s_standard, s_standard, s_standard, s_date, s_standard, s_standard, s_standard, s_standard, s_date_time, s_date_time]
    end

    def add_statut_verification(count, output_sheet)
      output_sheet.add_data_validation("I2:I#{count + 1}",
                                       type: :list,
                                       formula1: "\"#{STATUT_VERIFICATION.join(',')}\"",
                                       showDropDown: false,
                                       showErrorMessage: true,
                                       errorTitle: '',
                                       error: 'Cliquez sur la flèche pour prendre une valeur',
                                       errorStyle: :stop,
                                       showInputMessage: true,
                                       promptTitle: '',
                                       prompt: 'Selectionnez une valeur dans la liste')
    end

    def output_header(workbook, output_sheet)
      s = workbook.styles
      header_style = s.add_style sz: 12, alignment: { horizontal: :center, vertical: :center }
      output_sheet.add_row(COLUMNS, style: header_style, height: 30)
    end

    def symbolize(name)
      name.tr('%', 'P').parameterize.underscore.to_sym
    end

    def title_regexps
      @title_regexps ||= COLUMNS.to_h { |name| [symbolize(name), Regexp.new(name, Regexp::IGNORECASE)] }
    end

    def titles
      @titles ||= title_regexps.keys
    end

    def mobile?(tel)
      tel.match?(/^8[789]/) && tel.length == 8
    end

    def normalize(tel)
      return unless tel

      str = tel.to_s
      str = str.strip
      str = str.gsub(%r{[.-/ ()]}, '')
      str.gsub(/^(\+?689)/, '')
    end
  end
end
