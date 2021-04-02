# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: 'Magic Benne <informatique@sefi.pf>'
  layout 'mailer'
end
