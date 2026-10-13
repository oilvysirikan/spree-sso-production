require 'rails_helper'
require_relative '../support/jotform_helpers'

RSpec.describe JotformSubmissionJob, type: :job do
  let(:country) { Spree::Country.find_by(iso: 'TH') || create(:country, iso: 'TH', iso3: 'THA', name: 'Thailand', states_required: false) }
  let(:store) { create(:store, default_country: country) }
  let(:connection) { JotformConnection.create!(store: store) }
  let(:answers) { jotform_answers }
  let(:submission) { connection.submissions.create!(submission_id: 'S1', payload: { 'answers' => answers }) }

  it 'creates a customer with an address and marks the submission processed' do
    expect { described_class.perform_now(submission.id) }.to change(Spree.user_class, :count).by(1)

    user = Spree.user_class.find_by(email: 'somchai@example.com')
    expect(user).to have_attributes(first_name: 'Somchai', last_name: 'Jaidee', phone: '081-234-5678')
    expect(user.private_metadata.dig('jotform', 'store_codes')).to eq([store.code])
    expect(user.private_metadata.dig('jotform', 'customer_codes', store.code)).to eq('CUST-001')

    address = user.bill_address
    expect(address).to have_attributes(address1: '99 Sukhumvit Rd', city: 'Bangkok', zipcode: '10110', country: country)
    expect(user.ship_address).to eq(address)

    expect(submission.reload).to have_attributes(status: 'processed', spree_user: user)
    expect(submission.processed_at).to be_present
  end

  it 'is idempotent when run twice' do
    described_class.perform_now(submission.id)

    expect { described_class.perform_now(submission.id) }
      .not_to change { [Spree.user_class.count, Spree::Address.count] }
  end

  it 'never overwrites an existing customer profile' do
    existing = create(:user, email: 'somchai@example.com', first_name: 'Original', last_name: 'Owner', phone: nil)

    expect { described_class.perform_now(submission.id) }.not_to change(Spree.user_class, :count)

    existing.reload
    expect(existing.first_name).to eq('Original')
    expect(existing.last_name).to eq('Owner')
    expect(existing.phone).to eq('081-234-5678')
  end

  it 'honours a custom field mapping' do
    connection.update!(field_mapping: { 'email' => 'contactEmail' })
    answers = { 'q9_contactEmail' => 'custom@example.com', 'q4_name' => { 'first' => 'A', 'last' => 'B' } }
    custom = connection.submissions.create!(submission_id: 'S2', payload: { 'answers' => answers })

    described_class.perform_now(custom.id)

    expect(Spree.user_class.find_by(email: 'custom@example.com')).to be_present
  end

  context 'without an email' do
    let(:answers) { jotform_answers('q3_email' => '') }

    it 'marks the submission failed without retrying' do
      expect { described_class.perform_now(submission.id) }.not_to raise_error

      expect(submission.reload.status).to eq('failed')
      expect(submission.error_message).to include('email')
    end
  end
end
