# frozen_string_literal: true

class CreateCardRelationships < ActiveRecord::Migration[8.1]
  def change
    create_table :card_relationships do |t|
      t.references :source_card, null: false, foreign_key: { to_table: :cards }
      t.references :target_card, null: false, foreign_key: { to_table: :cards }
      t.string :relationship_type, null: false
      t.references :created_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :card_relationships, [:source_card_id, :target_card_id, :relationship_type],
              unique: true, name: 'idx_card_relationships_unique'
    add_index :card_relationships, :relationship_type
  end
end
