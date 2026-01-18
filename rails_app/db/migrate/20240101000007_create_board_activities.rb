class CreateBoardActivities < ActiveRecord::Migration[8.0]
  def change
    create_table :board_activities do |t|
      t.references :board, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :activity_type, null: false
      t.references :card, foreign_key: true
      t.datetime :last_active_at

      t.timestamps
    end

    add_index :board_activities, [:board_id, :user_id]
    add_index :board_activities, :activity_type
  end
end
