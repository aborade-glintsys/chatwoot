class CreateGlintReachSchedules < ActiveRecord::Migration[7.2]
  def change
    create_table :glint_reach_schedules do |t|
      t.bigint :account_id, null: false
      t.bigint :content_variant_id, null: false
      t.bigint :approval_id, null: false
      t.bigint :scheduled_by_id, null: false
      t.datetime :scheduled_at, null: false
      t.string :timezone, null: false
      t.integer :status, null: false, default: 0
      t.integer :attempts, null: false, default: 0
      t.string :error_code
      t.string :error_message, limit: 500
      t.datetime :dispatch_started_at
      t.datetime :finished_at
      t.timestamps
    end

    add_indexes_and_keys
  end

  private

  def add_indexes_and_keys
    # A variant can have at most one live (pending or dispatching) schedule.
    add_index :glint_reach_schedules, :content_variant_id, unique: true, where: 'status IN (0, 1)',
                                                           name: 'index_glint_reach_schedules_one_live_per_variant'
    add_index :glint_reach_schedules, [:status, :scheduled_at]
    add_index :glint_reach_schedules, [:account_id, :scheduled_at]
    add_foreign_key :glint_reach_schedules, :glint_reach_content_variants, column: :content_variant_id, on_delete: :cascade
    add_foreign_key :glint_reach_schedules, :glint_reach_approvals, column: :approval_id, on_delete: :cascade
  end
end
