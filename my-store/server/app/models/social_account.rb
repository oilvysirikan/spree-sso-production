class SocialAccount < ApplicationRecord
  # Only spree_customer_id links an account to a customer. legacy_spree_user_id
  # holds values from 20261017000001 that referenced spree_users; those ids are
  # not customer ids and are kept untouched for manual review.
  belongs_to :spree_customer, class_name: Spree.customer_class.to_s, optional: true

  validates :provider, presence: true
  validates :uid, presence: true
  validates :uid, uniqueness: { scope: :provider }

  scope :line, -> { where(provider: 'line') }

  def line_display_name = profile_data&.dig('name')
  def line_picture_url  = profile_data&.dig('picture')
end
