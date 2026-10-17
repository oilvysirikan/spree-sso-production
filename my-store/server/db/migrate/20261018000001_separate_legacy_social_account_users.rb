# 20261017000001_create_social_accounts created social_accounts.spree_user_id
# (NOT NULL, FK -> spree_users). On Spree 6 customers live in spree_customers,
# and an id in spree_users is NOT the same person as that id in
# spree_customers, so existing values must never be reinterpreted.
#
# This migration changes no row data:
# - spree_user_id is renamed to legacy_spree_user_id. Values and the FK to
#   spree_users are kept as-is for manual review; the column becomes nullable.
# - spree_customer_id is added, nullable, FK -> spree_customers. It is empty
#   for every existing row, so the constraint is fully validated immediately.
#   Legacy rows stay linked to no customer until someone reviews them.
class SeparateLegacySocialAccountUsers < ActiveRecord::Migration[8.1]
  def up
    if column_exists?(:social_accounts, :spree_user_id)
      rename_column :social_accounts, :spree_user_id, :legacy_spree_user_id
      change_column_null :social_accounts, :legacy_spree_user_id, true
    end

    return if column_exists?(:social_accounts, :spree_customer_id)

    add_reference :social_accounts, :spree_customer, null: true, index: true,
                  foreign_key: { to_table: :spree_customers }
  end

  def down
    if select_value('SELECT 1 FROM social_accounts WHERE spree_customer_id IS NOT NULL LIMIT 1')
      raise ActiveRecord::IrreversibleMigration,
            'social_accounts rows are linked to spree_customers; resolve them manually before rolling back'
    end
    if select_value('SELECT 1 FROM social_accounts WHERE legacy_spree_user_id IS NULL LIMIT 1')
      raise ActiveRecord::IrreversibleMigration,
            'social_accounts rows have no legacy_spree_user_id; spree_user_id cannot be NOT NULL again'
    end

    remove_reference :social_accounts, :spree_customer, foreign_key: { to_table: :spree_customers }, index: true
    change_column_null :social_accounts, :legacy_spree_user_id, false
    rename_column :social_accounts, :legacy_spree_user_id, :spree_user_id
  end
end
