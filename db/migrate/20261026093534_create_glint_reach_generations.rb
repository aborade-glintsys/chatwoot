class CreateGlintReachGenerations < ActiveRecord::Migration[7.2]
  def change
    create_table :glint_reach_generations do |t|
      target_columns(t)
      outcome_columns(t)
      t.timestamps
    end

    add_index :glint_reach_generations, [:account_id, :created_at]
    add_index :glint_reach_generations, [:campaign_id, :status]
    add_index :glint_reach_generations, :content_item_id
    add_index :glint_reach_generations, :content_variant_id
    add_foreign_key :glint_reach_generations, :glint_reach_campaigns, column: :campaign_id, on_delete: :cascade
  end

  private

  def target_columns(table)
    table.bigint :account_id, null: false
    table.bigint :campaign_id, null: false
    table.bigint :content_item_id
    table.bigint :content_variant_id
    table.bigint :requested_by_id, null: false
    table.integer :kind, null: false
    table.integer :status, null: false, default: 0
    # Request options (platforms, count, user instruction). Never the assembled prompt.
    table.jsonb :options, null: false, default: {}
  end

  def outcome_columns(table)
    # Validated output summary.
    table.jsonb :result, null: false, default: {}
    table.string :provider
    table.string :model
    table.integer :input_tokens
    table.integer :output_tokens
    table.integer :credit_multiplier
    table.string :error_code
    table.string :error_message, limit: 500
    table.datetime :started_at
    table.datetime :completed_at
  end
end
