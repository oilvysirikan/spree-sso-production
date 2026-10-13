class CreateJotformConnections < ActiveRecord::Migration[8.1]
  def change
    create_table :jotform_connections do |t|
      t.references :store, null: false, foreign_key: { to_table: :spree_stores }
      t.string :name
      t.string :form_id
      t.string :token, null: false
      t.jsonb :field_mapping, null: false, default: {}
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :jotform_connections, :token, unique: true

    create_table :jotform_submissions do |t|
      t.references :jotform_connection, null: false, foreign_key: true
      t.references :spree_user, foreign_key: { to_table: :spree_users }
      t.string :submission_id, null: false
      t.string :status, null: false, default: 'pending'
      t.jsonb :payload, null: false, default: {}
      t.text :error_message
      t.datetime :processed_at

      t.timestamps
    end
    add_index :jotform_submissions, [:jotform_connection_id, :submission_id],
              unique: true, name: 'index_jotform_submissions_on_connection_and_submission'
    add_index :jotform_submissions, :status
  end
end
