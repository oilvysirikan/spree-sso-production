class AddProfileDataToSocialAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :social_accounts, :access_token, :string
    add_column :social_accounts, :token_expires_at, :datetime
    add_column :social_accounts, :profile_data, :jsonb, default: {}

    add_index :social_accounts, [:provider, :uid], unique: true,
              name: 'index_social_accounts_on_provider_and_uid'
  end
end
