class CreateCards < ActiveRecord::Migration[8.0]
  def change
    create_table :cards do |t|
      t.references :board, null: false, foreign_key: true
      t.references :column, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :priority, default: 'medium'
      t.integer :position, default: 0
      t.date :due_date
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :cards, [:column_id, :position]
    add_index :cards, :priority
  end
end
