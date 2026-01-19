class CreateMcpToolCalls < ActiveRecord::Migration[8.0]
  def change
    create_table :mcp_tool_calls do |t|
      t.references :mcp_client_connection, foreign_key: true, null: true
      t.references :user, foreign_key: true, null: true
      t.string :tool_name, null: false
      t.string :direction, null: false
      t.json :arguments, default: {}
      t.json :result
      t.string :status, null: false
      t.text :error_message
      t.integer :latency_ms
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    add_index :mcp_tool_calls, :tool_name
    add_index :mcp_tool_calls, :direction
    add_index :mcp_tool_calls, :status
    add_index :mcp_tool_calls, :created_at
  end
end
