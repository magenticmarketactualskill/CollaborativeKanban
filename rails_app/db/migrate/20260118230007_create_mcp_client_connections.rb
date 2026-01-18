class CreateMcpClientConnections < ActiveRecord::Migration[8.0]
  def change
    create_table :mcp_client_connections do |t|
      t.references :user, foreign_key: true, null: true
      t.string :name, null: false
      t.string :url, null: false
      t.boolean :enabled, default: true, null: false
      t.string :auth_type, default: "none"
      t.string :auth_token
      t.string :status, default: "disconnected"
      t.datetime :last_connected_at
      t.text :last_error
      t.json :cached_tools, default: []
      t.json :cached_resources, default: []
      t.json :cached_prompts, default: []
      t.json :options, default: {}
      t.timestamps
    end

    add_index :mcp_client_connections, [ :user_id, :name ], unique: true
    add_index :mcp_client_connections, :status
    add_index :mcp_client_connections, :enabled
  end
end
