class SocialAccount < ApplicationRecord
  belongs_to :spree_user, class_name: Spree.user_class.to_s

  validates :provider, presence: true
  validates :uid, presence: true
  validates :uid, uniqueness: { scope: :provider }

  scope :line, -> { where(provider: 'line') }

  def line_display_name = profile_data&.dig('name')
  def line_picture_url  = profile_data&.dig('picture')
end
