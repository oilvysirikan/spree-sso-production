require 'rails_helper'

RSpec.describe 'Api::JotformSubmissions', type: :request do
  let(:connection) { JotformConnection.create!(store: create(:store), create_customers: false) }
  let!(:submission) do
    connection.submissions.create!(
      submission_id: 'S1', status: 'processed',
      payload: { 'form_id' => '262853852830463', 'pretty' => 'ชื่อ - นามสกุลภาษาไทย:สมชาย ใจดี, เบอร์โทรศัพท์ติดต่อได้:0812345678', 'answers' => { 'q3_input3' => 'สมชาย ใจดี' } }
    )
  end

  def auth(user = 'spree', password = 'spree123')
    { 'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials(user, password) }
  end

  it 'requires HTTP Basic credentials' do
    get '/api/jotform/submissions'
    expect(response).to have_http_status(:unauthorized)

    get '/api/jotform/submissions', headers: auth('spree', 'wrong')
    expect(response).to have_http_status(:unauthorized)
  end

  it 'lists submissions as JSON' do
    get '/api/jotform/submissions', headers: auth

    expect(response).to have_http_status(:ok)
    expect(json_response.first).to include('submission_id' => 'S1', 'status' => 'processed', 'store' => connection.store.code)
    expect(json_response.first['pretty']).to include('สมชาย ใจดี')
  end

  it 'exports CSV with a UTF-8 BOM for Excel' do
    get '/api/jotform/submissions.csv', headers: auth

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('text/csv')
    body = response.body.dup.force_encoding('UTF-8')
    expect(body).to start_with("﻿")
    expect(body).to include('สมชาย ใจดี')
  end

  it 'filters by status' do
    connection.submissions.create!(submission_id: 'S2', status: 'failed')

    get '/api/jotform/submissions', params: { status: 'failed' }, headers: auth

    expect(json_response.map { |s| s['submission_id'] }).to eq(['S2'])
  end
end
