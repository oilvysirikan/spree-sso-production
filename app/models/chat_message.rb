class ChatMessage < ApplicationRecord
  belongs_to :chat_session
  
  validates :role, inclusion: { in: ['user', 'assistant', 'system'] }
end
