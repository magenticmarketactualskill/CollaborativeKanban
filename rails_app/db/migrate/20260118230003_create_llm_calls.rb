class CreateLlmCalls < ActiveRecord::Migration[8.1]
  def change
    create_table :llm_calls do |t|
      t.references :llm_configuration, null: false, foreign_key: true
      t.string :task_type, null: false
      t.text :prompt
      t.text :response_content
      t.string :model
      t.string :provider
      t.integer :latency_ms
      t.string :status, default: "pending", null: false
      t.text :error_message
      t.integer :input_tokens
      t.integer :output_tokens
      t.json :metadata, default: {}
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end

    add_index :llm_calls, :task_type
    add_index :llm_calls, :status
    add_index :llm_calls, :provider
    add_index :llm_calls, :created_at
    add_index :llm_calls, [:llm_configuration_id, :status]
  end
end
