class CreateColumns < ActiveRecord::Migration[8.0]
  def change
    create_table :columns do |t|
      t.references :board, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :columns, [:board_id, :position]
  end
end
