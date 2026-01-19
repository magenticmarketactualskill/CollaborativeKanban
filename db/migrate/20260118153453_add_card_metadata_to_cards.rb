class AddCardMetadataToCards < ActiveRecord::Migration[8.1]
  def change
    add_column :cards, :card_metadata, :json, default: {}
    add_column :cards, :ai_summary, :text
    add_column :cards, :ai_analyzed_at, :datetime
  end
end
