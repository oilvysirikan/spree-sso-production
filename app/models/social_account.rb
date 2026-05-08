class SocialAccount < ApplicationRecord
  belongs_to :spree_user, class_name: 'Spree::User'
  
  validates :provider, presence: true
  validates :uid, presence: true
  validates :provider, uniqueness: { scope: :spree_user_id }
end
