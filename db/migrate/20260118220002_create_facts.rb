class CreateFacts < ActiveRecord::Migration[8.0]
  def change
    create_table :facts do |t|
      t.references :subject_entity, null: false, foreign_key: { to_table: :entities }
      t.string :predicate, null: false       # The relationship verb: "owns", "manages", "depends_on", "is_part_of"
      t.references :object_entity, foreign_key: { to_table: :entities }  # Nullable for literal facts
      t.string :object_value                 # For literal values: "2024-01-15", "high", "v2.0"
      t.string :object_type                  # string, date, number, boolean, reference
      t.references :domain, null: false, foreign_key: true
      t.float :confidence, default: 1.0      # AI confidence score
      t.string :extraction_method            # manual, ai_llm, ai_pattern, inferred
      t.datetime :valid_from                 # Temporal facts
      t.datetime :valid_until
      t.boolean :negated, default: false     # For negative facts: "X does NOT depend on Y"
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :facts, :predicate
    add_index :facts, [:subject_entity_id, :predicate, :object_entity_id],
              unique: true,
              where: "object_entity_id IS NOT NULL AND valid_until IS NULL",
              name: "idx_facts_unique_entity_relationship"
    add_index :facts, [:subject_entity_id, :predicate, :object_value],
              unique: true,
              where: "object_value IS NOT NULL AND valid_until IS NULL",
              name: "idx_facts_unique_value_relationship"
    add_index :facts, :extraction_method
  end
end
