# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Dossiers', type: :request do
  describe 'GET /search' do
    it 'returns http success' do
      get '/dossier/search'
      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET /enqueue' do
    it 'returns http success' do
      get '/dossier/enqueue'
      expect(response).to have_http_status(:success)
    end
  end
end
