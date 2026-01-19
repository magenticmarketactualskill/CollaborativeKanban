class CreateBoards < ActiveRecord::Migration[8.0]
  def change
    create_table :boards do |t|
      t.string :name, null: false
      t.text :description
      t.string :level, default: 'personal'
      t.references :owner, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :boards, :level
  end
end
