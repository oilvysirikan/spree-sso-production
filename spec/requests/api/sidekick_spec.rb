require 'rails_helper'

RSpec.describe "Api::Sidekicks", type: :request do
  describe "GET /chat" do
    it "returns http success" do
      get "/api/sidekick/chat"
      expect(response).to have_http_status(:success)
    end
  end

end
