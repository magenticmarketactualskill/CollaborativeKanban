class AddCardTypeToCards < ActiveRecord::Migration[8.1]
  def change
    add_column :cards, :card_type, :string, default: "task", null: false
    add_column :cards, :type_inference_confidence, :string
    add_column :cards, :type_inferred_at, :datetime

    add_index :cards, :card_type
  end
end
