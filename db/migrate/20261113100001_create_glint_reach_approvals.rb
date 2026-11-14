class CreateGlintReachApprovals < ActiveRecord::Migration[7.2]
  def change
    create_table :glint_reach_approvals do |t|
      t.bigint :account_id, null: false
      t.bigint :content_variant_id, null: false
      t.bigint :reviewer_id, null: false
      t.integer :decision, null: false
      t.text :feedback
      # SHA-256 of the reviewed content; publishing is refused if the content no longer matches.
      t.string :content_digest, null: false
      t.datetime :created_at, null: false
    end

    add_index :glint_reach_approvals, [:content_variant_id, :id]
    add_index :glint_reach_approvals, :account_id
    add_foreign_key :glint_reach_approvals, :glint_reach_content_variants, column: :content_variant_id, on_delete: :cascade
  end
end
