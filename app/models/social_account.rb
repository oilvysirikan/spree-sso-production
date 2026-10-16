class SocialAccount < ApplicationRecord
  belongs_to :spree_user, class_name: 'Spree::User'

  validates :provider, presence: true
  validates :uid, presence: true
  validates :uid, uniqueness: { scope: :provider }

  scope :line, -> { where(provider: 'line') }
  scope :entra_id, -> { where(provider: 'entra_id') }

  def line_display_name = profile_data&.dig('name')
  def line_picture_url  = profile_data&.dig('picture')
end
