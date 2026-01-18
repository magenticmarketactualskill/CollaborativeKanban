class AddCostAndSpeedToLlmConfigurations < ActiveRecord::Migration[8.1]
  def change
    add_column :llm_configurations, :cost_per_input_token, :decimal, precision: 12, scale: 10
    add_column :llm_configurations, :cost_per_output_token, :decimal, precision: 12, scale: 10
    add_column :llm_configurations, :speed_rating, :string

    add_index :llm_configurations, :speed_rating
  end
end
