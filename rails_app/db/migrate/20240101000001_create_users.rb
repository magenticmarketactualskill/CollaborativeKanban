class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :open_id, null: false
      t.string :name, null: false
      t.string :email, null: false
      t.string :login_method, default: 'email'
      t.string :role, default: 'user'
      t.datetime :last_signed_in_at

      t.timestamps
    end

    add_index :users, :open_id, unique: true
    add_index :users, :email, unique: true
  end
end
