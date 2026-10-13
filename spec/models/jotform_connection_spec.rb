require 'rails_helper'

RSpec.describe JotformConnection, type: :model do
  let(:store) { create(:store) }

  it 'generates a unique webhook token' do
    a = described_class.create!(store: store, form_id: '1')
    b = described_class.create!(store: store, form_id: '2')

    expect(a.token).to be_present
    expect(a.token.length).to eq(40)
    expect(a.token).not_to eq(b.token)
    expect(a.webhook_path).to eq("/api/jotform/webhook/#{a.token}")
  end

  it 'merges custom field mapping over the defaults' do
    connection = described_class.new(store: store, field_mapping: { 'email' => 'contactEmail' })

    expect(connection.mapping['email']).to eq('contactEmail')
    expect(connection.mapping['first_name']).to eq('name.first')
  end

  it 'rejects unknown mapping keys' do
    connection = described_class.new(store: store, field_mapping: { 'password' => 'q1_pw' })

    expect(connection).not_to be_valid
    expect(connection.errors[:field_mapping].join).to include('password')
  end

  it 'does not allow the same form twice in one store' do
    described_class.create!(store: store, form_id: '262853852830463')

    expect(described_class.new(store: store, form_id: '262853852830463')).not_to be_valid
  end

  describe '#form_matches?' do
    it 'accepts any form when form_id is blank' do
      expect(described_class.new(form_id: nil).form_matches?('999')).to be(true)
    end

    it 'only accepts the configured form' do
      connection = described_class.new(form_id: '123')

      expect(connection.form_matches?('123')).to be(true)
      expect(connection.form_matches?('456')).to be(false)
    end
  end
end
