class CreateLlmConfigurations < ActiveRecord::Migration[8.1]
  def change
    create_table :llm_configurations do |t|
      t.string :name, null: false
      t.string :provider_type, null: false
      t.string :endpoint
      t.string :model, null: false
      t.string :api_key
      t.json :options, default: {}
      t.boolean :active, default: true, null: false
      t.boolean :default_for_type, default: false, null: false
      t.integer :priority, default: 0, null: false
      t.references :user, foreign_key: true

      t.timestamps
    end

    add_index :llm_configurations, :provider_type
    add_index :llm_configurations, :active
    add_index :llm_configurations, [:provider_type, :default_for_type], unique: true, where: "default_for_type = true"
    add_index :llm_configurations, [:user_id, :name], unique: true
  end
end
