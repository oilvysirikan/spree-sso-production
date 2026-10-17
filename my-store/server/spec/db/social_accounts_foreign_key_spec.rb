require 'rails_helper'

RSpec.describe 'social_accounts foreign key' do
  let(:foreign_keys) { ActiveRecord::Base.connection.foreign_keys(:social_accounts) }

  it 'references spree_customers, not spree_users' do
    targets = foreign_keys.select { |fk| fk.column == 'spree_user_id' }.map(&:to_table)

    expect(targets).to eq(['spree_customers'])
  end

  it 'rejects a row that does not point at a customer' do
    missing_id = (Spree.customer_class.maximum(:id) || 0) + 1_000

    expect {
      SocialAccount.new(spree_user_id: missing_id, provider: 'line', uid: 'U-orphan').save!(validate: false)
    }.to raise_error(ActiveRecord::InvalidForeignKey)
  end
end
