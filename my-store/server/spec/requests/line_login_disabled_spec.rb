require 'rails_helper'
require_relative '../support/jotform_helpers' # not_change matcher

RSpec.describe 'LINE Login while disabled', type: :request do
  let(:customer) { create(:customer) }
  let!(:social) { SocialAccount.create!(spree_customer: customer, provider: 'line', uid: 'U-existing') }

  before { allow(HTTParty).to receive(:post).and_call_original }

  it 'is switched off in code' do
    expect(LineLoginGate::ENABLED).to be(false)
  end

  describe 'POST /api/line/callback' do
    it 'returns 404 without calling LINE or writing anything' do
      expect {
        post '/api/line/callback', params: { id_token: 'any-token' }, as: :json
      }.to not_change(SocialAccount, :count)
        .and not_change(Spree.customer_class, :count)
        .and not_change { social.reload.updated_at }

      expect(response).to have_http_status(:not_found)
      expect(HTTParty).not_to have_received(:post)
      expect(session[:line_user_id]).to be_nil
    end

    it 'stays closed when LINE_LOGIN_ENABLED is set' do
      ENV['LINE_LOGIN_ENABLED'] = 'true'
      post '/api/line/callback', params: { id_token: 'any-token' }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(HTTParty).not_to have_received(:post)
    ensure
      ENV.delete('LINE_LOGIN_ENABLED')
    end
  end

  describe 'POST /api/line/logout' do
    it 'returns 404' do
      post '/api/line/logout', as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /member' do
    it 'returns 404 instead of redirecting to login or rendering a profile' do
      get '/member'

      expect(response).to have_http_status(:not_found)
      expect(response.body).to be_empty
    end
  end

  describe 'GET /member/login' do
    it 'returns 404 and does not serve the LIFF login page' do
      get '/member/login'

      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include('liff')
    end
  end
end
