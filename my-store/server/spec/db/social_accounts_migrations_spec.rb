require 'rails_helper'

# Exercises 20261017000001_create_social_accounts (FK -> spree_users) and
# 20261018000001_separate_legacy_social_account_users. Postgres DDL is
# transactional, so each example's schema changes roll back with the test.
RSpec.describe 'social_accounts migrations' do
  let(:old_version) { '20261017000001' }
  let(:new_version) { '20261018000001' }
  let(:connection) { ActiveRecord::Base.connection }

  def migration(version)
    path = Dir[Rails.root.join("db/migrate/#{version}_*.rb")].first
    require path
    File.basename(path, '.rb').sub(/\A\d+_/, '').camelize.constantize.new
  end

  def run_migration(version, direction)
    ActiveRecord::Migration.suppress_messages { migration(version).migrate(direction) }
    reset_schema_cache
  end

  def reset_schema_cache
    connection.schema_cache.clear!
    SocialAccount.reset_column_information
  end

  def columns
    connection.columns(:social_accounts).index_by(&:name)
  end

  def fk_for(column)
    connection.foreign_keys(:social_accounts).find { |fk| fk.column == column }
  end

  # Puts the table back into the state left by 20261017000001 alone.
  def as_if_only_old_migration_ran
    run_migration(new_version, :down)
    expect(columns.keys).to include('spree_user_id')
    expect(columns.keys).not_to include('spree_customer_id', 'legacy_spree_user_id')
  end

  def expect_final_schema
    expect(columns.keys).to include('spree_customer_id', 'legacy_spree_user_id')
    expect(columns.keys).not_to include('spree_user_id')
    expect(columns['spree_customer_id'].null).to be(true)
    expect(columns['legacy_spree_user_id'].null).to be(true)

    customer_fk = fk_for('spree_customer_id')
    expect(customer_fk.to_table).to eq('spree_customers')
    expect(customer_fk.validated?).to be(true)
    expect(fk_for('legacy_spree_user_id').to_table).to eq('spree_users')
  end

  after { reset_schema_cache }

  it 'leaves the test database (built by db:prepare) in the final shape' do
    expect_final_schema
  end

  context 'on a fresh database' do
    it 'runs 20261017000001 and then reaches and applies 20261018000001' do
      run_migration(new_version, :down)
      run_migration(old_version, :down)
      expect(connection.table_exists?(:social_accounts)).to be(false)

      run_migration(old_version, :up)
      expect(fk_for('spree_user_id').to_table).to eq('spree_users')

      run_migration(new_version, :up)
      expect_final_schema
    end
  end

  context 'when 20261017000001 already ran and the table is empty' do
    it 'applies cleanly' do
      as_if_only_old_migration_ran

      run_migration(new_version, :up)

      expect_final_schema
      expect(SocialAccount.count).to eq(0)
    end
  end

  context 'when old rows reference spree_users ids that are not customers' do
    it 'keeps the rows and their legacy ids, and links them to no customer' do
      as_if_only_old_migration_ran

      # A customer and a legacy user that happen to share the same id are
      # different people and must not be linked.
      customer = create(:customer)
      connection.execute(<<~SQL)
        INSERT INTO spree_users (id, email, created_at, updated_at)
        VALUES (#{customer.id}, 'legacy-user@example.com', NOW(), NOW())
      SQL
      connection.execute(<<~SQL)
        INSERT INTO social_accounts (spree_user_id, provider, uid, created_at, updated_at)
        VALUES (#{customer.id}, 'line', 'U-legacy', NOW(), NOW())
      SQL

      expect { run_migration(new_version, :up) }
        .not_to(change { connection.select_value('SELECT COUNT(*) FROM social_accounts') })

      account = SocialAccount.find_by!(uid: 'U-legacy')
      expect(account.legacy_spree_user_id).to eq(customer.id)
      expect(account.spree_customer_id).to be_nil
      expect(account.spree_customer).to be_nil
      expect(SocialAccount.where(spree_customer_id: customer.id)).to be_empty
    end
  end

  it 'rejects a spree_customer_id that is not a customer' do
    missing_id = (Spree.customer_class.maximum(:id) || 0) + 1_000

    expect {
      SocialAccount.new(spree_customer_id: missing_id, provider: 'line', uid: 'U-orphan').save!(validate: false)
    }.to raise_error(ActiveRecord::InvalidForeignKey)
  end

  it 'refuses to roll back once accounts are linked to customers' do
    SocialAccount.create!(spree_customer: create(:customer), provider: 'line', uid: 'U-linked')

    expect { run_migration(new_version, :down) }.to raise_error(ActiveRecord::IrreversibleMigration)
  end
end
