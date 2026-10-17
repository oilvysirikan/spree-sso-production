require 'rails_helper'

RSpec.describe "Api::Ssos", type: :request do
  describe "POST /api/sso/validate_token" do
    it "rejects a request without a token" do
      post "/api/sso/validate_token", as: :json
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "POST /api/sso/create_user" do
    it "rejects a request without user data" do
      post "/api/sso/create_user", as: :json
      expect(response).to have_http_status(:bad_request)
    end
  end
end
