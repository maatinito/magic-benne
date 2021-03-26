# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'TaskExecutions', type: :request do
  describe 'GET /discard' do
    it 'returns http success' do
      get '/task_execution/discard'
      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET /undiscard' do
    it 'returns http success' do
      get '/task_execution/undiscard'
      expect(response).to have_http_status(:success)
    end
  end
end
