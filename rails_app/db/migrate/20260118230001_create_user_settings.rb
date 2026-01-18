class CreateUserSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :user_settings do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }

      # Local LLM Settings
      t.string :local_endpoint, default: 'http://localhost:11434/v1'
      t.string :local_model, default: 'llama3.2'
      t.string :local_api_key

      # Remote API Settings
      t.string :remote_provider, default: 'openai'
      t.string :remote_api_key
      t.string :remote_endpoint
      t.string :remote_model, default: 'gpt-4o-mini'

      # Active Provider Selection
      t.string :active_provider, default: 'local', null: false

      t.timestamps
    end
  end
end
