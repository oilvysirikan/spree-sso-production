class ChatSession < ApplicationRecord
  belongs_to :user, class_name: 'Spree::AdminUser', foreign_key: 'user_id'
  has_many :messages, class_name: 'ChatMessage'
  
  scope :active, -> { where(status: ['active', 'processing']) }
end
