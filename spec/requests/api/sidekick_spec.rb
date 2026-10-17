require 'rails_helper'

RSpec.describe "Api::Sidekicks", type: :request do
  describe "POST /api/sidekick/chat" do
    it "rejects unauthenticated requests" do
      post "/api/sidekick/chat", params: { message: 'hi' }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
