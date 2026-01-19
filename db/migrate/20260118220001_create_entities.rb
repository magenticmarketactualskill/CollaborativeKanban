class CreateEntities < ActiveRecord::Migration[8.0]
  def change
    create_table :entities do |t|
      t.string :name, null: false           # Canonical name
      t.json :aliases, default: []           # Alternative names/spellings
      t.string :entity_type, null: false     # person, system, concept, location, organization, artifact
      t.text :description
      t.references :domain, null: false, foreign_key: true
      t.json :properties, default: {}        # Flexible key-value attributes
      t.string :external_id                  # Link to external systems (Jira, GitHub, etc.)
      t.string :external_source              # Which external system
      t.float :confidence, default: 1.0      # 1.0 = user-created, < 1.0 = AI-extracted
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :entities, [:domain_id, :name], unique: true
    add_index :entities, :entity_type
    add_index :entities, [:external_source, :external_id], unique: true, where: "external_id IS NOT NULL"
  end
end
