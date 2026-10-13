require 'rails_helper'
require_relative '../../support/jotform_helpers'

RSpec.describe 'Api::Jotform', type: :request do
  # config/application.rb pins the adapter to Sidekiq; ActiveJob matchers need :test.
  around do |example|
    original = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = original
  end

  let(:store) { create(:store) }
  let!(:connection) { JotformConnection.create!(store: store, form_id: '262853852830463') }

  def post_webhook(token: connection.token, form_id: '262853852830463', submission_id: '5912345678901234567', raw: jotform_answers.to_json)
    post "/api/jotform/webhook/#{token}", params: { formID: form_id, submissionID: submission_id, rawRequest: raw }
  end

  it 'stores the submission and enqueues processing without doing it inline' do
    expect { post_webhook }
      .to change(JotformSubmission, :count).by(1)
      .and have_enqueued_job(JotformSubmissionJob)
      .and not_change(Spree.user_class, :count)

    expect(response).to have_http_status(:ok)
    expect(json_response[:status]).to eq('accepted')

    submission = JotformSubmission.last
    expect(submission.jotform_connection).to eq(connection)
    expect(submission.status).to eq('pending')
    expect(submission.answers['q3_email']).to eq('Somchai@Example.com')
  end

  it 'returns 200 for a duplicate delivery and does not enqueue again' do
    post_webhook
    clear_enqueued_jobs

    expect { post_webhook }
      .to not_change(JotformSubmission, :count)
      .and not_have_enqueued_job(JotformSubmissionJob)

    expect(response).to have_http_status(:ok)
    expect(json_response[:status]).to eq('duplicate')
  end

  it 'returns 404 for an unknown token' do
    expect { post_webhook(token: 'nope') }.not_to change(JotformSubmission, :count)
    expect(response).to have_http_status(:not_found)
  end

  it 'returns 404 for an inactive connection' do
    connection.update!(active: false)

    post_webhook
    expect(response).to have_http_status(:not_found)
  end

  it 'returns 403 when the form id does not match the connection' do
    expect { post_webhook(form_id: '111') }.not_to change(JotformSubmission, :count)
    expect(response).to have_http_status(:forbidden)
  end

  it 'returns 422 for a malformed rawRequest' do
    post_webhook(raw: 'not json')
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'returns 422 without a submission id' do
    post_webhook(submission_id: '')
    expect(response).to have_http_status(:unprocessable_content)
  end
end
