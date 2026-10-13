require 'rails_helper'

RSpec.describe JotformSubmission, type: :model do
  let(:connection) { JotformConnection.create!(store: create(:store)) }

  it 'is unique per connection and Jotform submission id' do
    described_class.create!(jotform_connection: connection, submission_id: 'S1')

    duplicate = described_class.new(jotform_connection: connection, submission_id: 'S1')
    expect(duplicate).not_to be_valid
    expect(duplicate.errors.of_kind?(:submission_id, :taken)).to be(true)
  end

  it 'allows the same submission id on another connection' do
    other = JotformConnection.create!(store: create(:store))
    described_class.create!(jotform_connection: connection, submission_id: 'S1')

    expect(described_class.new(jotform_connection: other, submission_id: 'S1')).to be_valid
  end

  it 'is backed by a unique database index' do
    described_class.create!(jotform_connection: connection, submission_id: 'S1')
    duplicate = described_class.new(jotform_connection: connection, submission_id: 'S1')

    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
