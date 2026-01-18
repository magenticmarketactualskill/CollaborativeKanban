class CreateLlmStages < ActiveRecord::Migration[8.1]
  def change
    create_table :llm_stages do |t|
      t.references :llm_call, null: false, foreign_key: true
      t.string :name, null: false
      t.string :stage_type
      t.integer :position, default: 0, null: false
      t.text :prompt
      t.text :response_content
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

    add_index :llm_stages, :name
    add_index :llm_stages, :stage_type
    add_index :llm_stages, :status
    add_index :llm_stages, [:llm_call_id, :position]
  end
end
