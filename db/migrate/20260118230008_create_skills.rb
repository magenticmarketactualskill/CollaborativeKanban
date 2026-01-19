class CreateSkills < ActiveRecord::Migration[8.0]
  def change
    create_table :skills do |t|
      t.references :user, foreign_key: true, null: true
      t.string :name, null: false
      t.string :slug, null: false
      t.string :version, default: "1.0.0"
      t.text :description
      t.string :category
      t.json :parameters, default: []
      t.text :prompt_template, null: false
      t.json :workflow_steps, default: []
      t.json :dependencies, default: []
      t.json :metadata, default: {}
      t.boolean :enabled, default: true, null: false
      t.boolean :system_skill, default: false
      t.string :source
      t.string :source_file
      t.timestamps
    end

    add_index :skills, [ :user_id, :slug ], unique: true
    add_index :skills, :category
    add_index :skills, :enabled
    add_index :skills, :system_skill
  end
end
