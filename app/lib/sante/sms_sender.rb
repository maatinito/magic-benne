# frozen_string_literal: true

require 'json'
module Sante
  class SmsSender
    API_URL = 'https://smsmasse.vodafone.pf/Api/Api.aspx'

    def initialize
      @key = ENV['VODAFONE_SECRET']
      @sender = ENV['VODAFONE_SENDER']
    end

    def url_params_for_sending(tel, message)
      tel = "689#{tel}" unless tel&.starts_with?('689')
      {
        fct: 'sms',
        mobile: tel,
        sms: message,
        sender: @sender,
        key: @key
      }
    end

    def url_params_for_ack(id)
      {
        fct: 'dlr',
        key: @key,
        msg_id: id
      }
    end

    ERROR_CODES = {
      '400': "absence d'id",
      '401': 'id non autorisé',
      '402': 'crédit insuffisant',
      '420': 'quota journalier dépassé',
      '430': 'contenu manquant',
      '431': 'destination manquante',
      '440': 'contenu trop long',
      '441': 'destination non autorisée',
      '442': 'sender non autorisé'
    }.freeze

    TIMEOUT = 3

    def send_sms(tel, message)
      # return if true

      response = Typhoeus.get(API_URL, timeout: TIMEOUT, ssl_verifypeer: false, verbose: false, params: url_params_for_sending(tel, message))
      if response.success?
        status = Hash.from_xml(response.body)['response']['status']
        pp status
        code = status['status_code']&.to_i
        if code == 200
          puts 'Message received'
          # sleep(10)
          response = Typhoeus.get(API_URL, timeout: TIMEOUT, ssl_verifypeer: false, verbose: false, params: url_params_for_ack(status['message_id']))
          pp Hash.from_xml(response.body)
        elsif code.between?(400, 499)
          raise status['status_msg']
        end
      elsif response.code&.between?(401, 499)
        message = ERROR_CODES[response.code&.to_s] || "Erreur inconnue #{response.code}"
        raise message
      else
        message = "Unable to contact Vodafone API: response code #{response.code} url=#{API_URL}"
        Rails.logger.error(message)
        raise message
      end
    end

    def parse_response_body(response)
      JSON.parse(response.body, symbolize_names: true)
    end
  end
end
