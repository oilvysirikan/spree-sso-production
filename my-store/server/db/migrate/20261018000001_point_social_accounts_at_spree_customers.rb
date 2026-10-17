# 20261017000001_create_social_accounts pointed social_accounts.spree_user_id
# at spree_users, but on Spree 6 customers live in spree_customers
# (Spree.customer_class). Fix the foreign key without assuming whether the
# earlier migration already ran in a given environment.
class PointSocialAccountsAtSpreeCustomers < ActiveRecord::Migration[8.1]
  def up
    remove_foreign_key :social_accounts, :spree_users, column: :spree_user_id, if_exists: true

    # NOT VALID: rows written under the old key (if any) don't block the
    # deploy; new and updated rows must reference a customer.
    unless foreign_key_exists?(:social_accounts, :spree_customers, column: :spree_user_id)
      add_foreign_key :social_accounts, :spree_customers, column: :spree_user_id, validate: false
    end
  end

  def down
    remove_foreign_key :social_accounts, :spree_customers, column: :spree_user_id, if_exists: true
    unless foreign_key_exists?(:social_accounts, :spree_users, column: :spree_user_id)
      add_foreign_key :social_accounts, :spree_users, column: :spree_user_id, validate: false
    end
  end
end
