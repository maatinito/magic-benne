# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch('MAIL_FROM', 'Magic Benne <clautier@idt.pf>')
  layout 'mailer'
end
