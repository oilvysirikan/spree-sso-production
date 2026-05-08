class CreateSocialAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :social_accounts do |t|
      t.references :spree_user, null: false, foreign_key: { to_table: :spree_users }
      t.string :provider
      t.string :uid

      t.timestamps
    end
  end
end
