class CreateBoardMembers < ActiveRecord::Migration[8.0]
  def change
    create_table :board_members do |t|
      t.references :board, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, default: 'viewer'

      t.timestamps
    end

    add_index :board_members, [:board_id, :user_id], unique: true
    add_index :board_members, :role
  end
end
