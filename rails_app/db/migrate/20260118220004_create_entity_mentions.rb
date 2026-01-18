class CreateEntityMentions < ActiveRecord::Migration[8.0]
  def change
    create_table :entity_mentions do |t|
      t.references :entity, null: false, foreign_key: true
      t.references :card, null: false, foreign_key: true
      t.string :mention_text, null: false    # The actual text that matched
      t.string :source_field, null: false    # title, description, comment
      t.integer :text_offset_start
      t.integer :text_offset_end
      t.float :confidence, default: 1.0
      t.string :extraction_method            # manual, ai_llm, ai_pattern, fuzzy_match
      t.timestamps
    end

    add_index :entity_mentions, [:card_id, :entity_id]
    add_index :entity_mentions, :mention_text
  end
end
