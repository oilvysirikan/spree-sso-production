class CreateSocialAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :social_accounts do |t|
      t.references :spree_user, null: false, foreign_key: { to_table: :spree_users }
      t.string :provider, null: false
      t.string :uid, null: false
      t.string :access_token
      t.datetime :token_expires_at
      t.jsonb :profile_data, default: {}
      t.timestamps
    end

    add_index :social_accounts, [:provider, :uid], unique: true,
              name: 'index_social_accounts_on_provider_and_uid'
  end
end
