require 'rails_helper'
require_relative '../support/jotform_helpers'

RSpec.describe JotformSubmissionJob, type: :job do
  let(:store) { create(:store, default_country_code: 'US') }
  let(:connection) { JotformConnection.create!(store: store) }
  let(:answers) do
    jotform_answers(
      'q6_address' => {
        'addr_line1' => '99 Main St', 'addr_line2' => 'Unit 5', 'city' => 'Los Angeles',
        'state' => 'California', 'postal' => '90001', 'country' => 'United States'
      }
    )
  end
  let(:submission) { connection.submissions.create!(submission_id: 'S1', payload: { 'answers' => answers }) }

  it 'creates a customer with an address and marks the submission processed' do
    expect { described_class.perform_now(submission.id) }.to change(Spree.customer_class, :count).by(1)

    customer = Spree.customer_class.find_by(email: 'somchai@example.com')
    expect(customer).to have_attributes(first_name: 'Somchai', last_name: 'Jaidee', phone: '081-234-5678')
    expect(customer.password_digest).to be_nil
    expect(customer.tag_list).to include('jotform')
    expect(customer.metadata.dig('jotform', 'store_codes')).to eq([store.code])
    expect(customer.metadata.dig('jotform', 'customer_codes', store.code)).to eq('CUST-001')

    address = customer.bill_address
    expect(address).to have_attributes(address1: '99 Main St', city: 'Los Angeles', postal_code: '90001',
                                       country_code: 'US', state_code: 'CA', owner: customer)
    expect(customer.ship_address).to eq(address)

    expect(submission.reload).to have_attributes(status: 'processed', spree_customer: customer, error_message: nil)
    expect(submission.processed_at).to be_present
  end

  it 'is idempotent when run twice' do
    described_class.perform_now(submission.id)

    expect { described_class.perform_now(submission.id) }
      .not_to change { [Spree.customer_class.count, Spree::Address.count] }
  end

  it 'reuses the address when the same customer submits again' do
    described_class.perform_now(submission.id)
    again = connection.submissions.create!(submission_id: 'S2', payload: { 'answers' => answers })

    expect { described_class.perform_now(again.id) }.not_to change(Spree::Address, :count)
  end

  it 'never overwrites an existing customer profile' do
    existing = create(:customer, email: 'somchai@example.com', first_name: 'Original', last_name: 'Owner', phone: nil)

    expect { described_class.perform_now(submission.id) }.not_to change(Spree.customer_class, :count)

    existing.reload
    expect(existing.first_name).to eq('Original')
    expect(existing.last_name).to eq('Owner')
    expect(existing.phone).to eq('081-234-5678')
  end

  it 'keeps the customer when Spree rejects the address' do
    answers['q6_address'] = answers['q6_address'].merge('state' => 'Atlantis')

    expect { described_class.perform_now(submission.id) }.to change(Spree.customer_class, :count).by(1)

    expect(Spree.customer_class.find_by(email: 'somchai@example.com').addresses).to be_empty
    expect(submission.reload.status).to eq('processed')
    expect(submission.error_message).to start_with('address not saved')
  end

  it 'falls back to the store default country' do
    answers['q6_address'] = answers['q6_address'].merge('country' => '')

    described_class.perform_now(submission.id)

    expect(Spree.customer_class.find_by(email: 'somchai@example.com').bill_address.country_code).to eq('US')
  end

  it 'honours a custom field mapping' do
    connection.update!(field_mapping: { 'email' => 'contactEmail' })
    custom_answers = { 'q9_contactEmail' => 'custom@example.com', 'q4_name' => { 'first' => 'A', 'last' => 'B' } }
    custom = connection.submissions.create!(submission_id: 'S3', payload: { 'answers' => custom_answers })

    described_class.perform_now(custom.id)

    expect(Spree.customer_class.find_by(email: 'custom@example.com')).to be_present
  end

  context 'when the connection only stores submissions' do
    let(:connection) { JotformConnection.create!(store: store, create_customers: false) }
    let(:answers) { { 'q3_input3' => 'สมชาย ใจดี', 'q10_input10' => '0812345678' } }

    it 'marks the submission processed without creating a customer' do
      expect { described_class.perform_now(submission.id) }.not_to change(Spree.customer_class, :count)

      expect(submission.reload).to have_attributes(status: 'processed', spree_customer: nil, error_message: nil)
    end
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
