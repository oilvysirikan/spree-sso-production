class CreateChatMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :chat_messages do |t|
      t.integer :chat_session_id
      t.string :role
      t.text :content

      t.timestamps
    end
  end
end
