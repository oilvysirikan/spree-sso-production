require 'rails_helper'

RSpec.describe "Api::Ssos", type: :request do
  describe "GET /validate_token" do
    it "returns http success" do
      get "/api/sso/validate_token"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /create_user" do
    it "returns http success" do
      get "/api/sso/create_user"
      expect(response).to have_http_status(:success)
    end
  end

end
