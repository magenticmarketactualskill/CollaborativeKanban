class CreateCardFacts < ActiveRecord::Migration[8.0]
  def change
    create_table :card_facts do |t|
      t.references :card, null: false, foreign_key: true
      t.references :fact, null: false, foreign_key: true
      t.string :role, null: false, default: "source"  # source, evidence, related
      t.integer :text_offset_start           # Where in card text this fact was found
      t.integer :text_offset_end
      t.string :source_field                 # title, description, comment, metadata
      t.timestamps
    end

    add_index :card_facts, [:card_id, :fact_id, :role], unique: true
    add_index :card_facts, :role
  end
end
