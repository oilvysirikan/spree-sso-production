class Spree::User < ApplicationRecord
  has_many :social_accounts, dependent: :destroy
  include Spree::UserAddress
  include Spree::UserMethods
  include Spree::UserPaymentSource

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
end
