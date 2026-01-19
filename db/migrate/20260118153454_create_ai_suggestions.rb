class CreateAiSuggestions < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_suggestions do |t|
      t.references :card, null: false, foreign_key: true
      t.string :suggestion_type, null: false
      t.string :field_name
      t.text :content, null: false
      t.string :provider
      t.string :status, default: "pending"
      t.datetime :acted_at

      t.timestamps
    end

    add_index :ai_suggestions, [:card_id, :status]
    add_index :ai_suggestions, :suggestion_type
  end
end
