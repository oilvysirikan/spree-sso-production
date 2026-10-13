require 'rails_helper'

RSpec.describe JotformConnection, type: :model do
  let(:store) { create(:store) }

  it 'generates a unique webhook token' do
    a = described_class.create!(store: store, form_id: '1')
    b = described_class.create!(store: store, form_id: '2')

    expect(a.token).to be_present
    expect(a.token.length).to eq(40)
    expect(a.token).not_to eq(b.token)
    expect(a.webhook_path).to eq("/api/jotform/webhook?token=#{a.token}")
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

  describe '.find_for_webhook' do
    let(:env_token) { 'e' * 40 }

    around do |example|
      keys = %w[JOTFORM_STORE JOTFORM_FORM_ID JOTFORM_WEBHOOK_TOKEN JOTFORM_CREATE_CUSTOMERS]
      saved = ENV.to_h.slice(*keys)
      ENV['JOTFORM_STORE'] = store.code
      ENV['JOTFORM_FORM_ID'] = '262853852830463'
      ENV['JOTFORM_WEBHOOK_TOKEN'] = env_token
      example.run
    ensure
      keys.each { |k| ENV.delete(k) }
      saved.each { |k, v| ENV[k] = v }
    end

    it 'finds an existing active connection by token' do
      connection = described_class.create!(store: store)

      expect(described_class.find_for_webhook(connection.token)).to eq(connection)
    end

    it 'creates the env-configured connection on first use' do
      connection = nil
      expect { connection = described_class.find_for_webhook(env_token) }.to change(described_class, :count).by(1)

      expect(connection).to have_attributes(store: store, form_id: '262853852830463', token: env_token)
      expect(described_class.find_for_webhook(env_token)).to eq(connection)
    end

    it 'can be configured to only store submissions' do
      ENV['JOTFORM_CREATE_CUSTOMERS'] = 'false'

      expect(described_class.find_for_webhook(env_token).create_customers).to be(false)
    end

    it 'finds the store by prefixed id' do
      ENV['JOTFORM_STORE'] = store.prefixed_id

      expect(described_class.find_for_webhook(env_token)&.store).to eq(store)
    end

    it 'ignores a token that does not match the env token' do
      expect(described_class.find_for_webhook('x' * 40)).to be_nil
    end

    it 'refuses short env tokens' do
      ENV['JOTFORM_WEBHOOK_TOKEN'] = 'short'

      expect(described_class.find_for_webhook('short')).to be_nil
    end

    it 'does not recreate a deactivated env connection' do
      described_class.find_for_webhook(env_token).update!(active: false)

      expect(described_class.find_for_webhook(env_token)).to be_nil
    end
  end
end
