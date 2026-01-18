class CreateDomains < ActiveRecord::Migration[8.0]
  def change
    create_table :domains do |t|
      t.string :name, null: false
      t.text :description
      t.references :board, null: false, foreign_key: true
      t.references :parent_domain, foreign_key: { to_table: :domains }
      t.string :color  # For UI visualization
      t.string :icon   # For UI visualization
      t.boolean :system_generated, default: false
      t.timestamps
    end

    add_index :domains, [:board_id, :name], unique: true
  end
end
