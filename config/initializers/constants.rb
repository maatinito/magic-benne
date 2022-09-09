# frozen_string_literal: true

SITE_NAME = ENV.fetch('SITE_NAME', 'Magic Benne')
MAIL_INFRA = ENV.fetch('MAIL_INFRA', nil)
MAIL_DEV  = ENV.fetch('MAIL_DEV', nil)
MAIL_FROM = "#{SITE_NAME} <#{ENV.fetch('MAIL_FROM', "mes-demarches#{64.chr}modernisation.gov.pf")}>".freeze
