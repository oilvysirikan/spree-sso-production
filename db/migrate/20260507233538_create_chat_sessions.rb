class CreateChatSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :chat_sessions do |t|
      t.integer :user_id
      t.string :status

      t.timestamps
    end
  end
end
