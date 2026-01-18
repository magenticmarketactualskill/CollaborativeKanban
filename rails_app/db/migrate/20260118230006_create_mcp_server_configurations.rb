class CreateMcpServerConfigurations < ActiveRecord::Migration[8.0]
  def change
    create_table :mcp_server_configurations do |t|
      t.references :user, foreign_key: true, null: true, index: { unique: true }
      t.string :name, null: false
      t.boolean :enabled, default: true, null: false
      t.integer :port, default: 3100
      t.string :auth_type, default: "none"
      t.string :auth_token
      t.json :enabled_tools, default: []
      t.json :enabled_resources, default: []
      t.json :options, default: {}
      t.timestamps
    end
  end
end
