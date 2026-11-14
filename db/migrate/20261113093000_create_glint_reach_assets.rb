class CreateGlintReachAssets < ActiveRecord::Migration[7.2]
  def change
    create_table :glint_reach_assets do |t|
      t.bigint :account_id, null: false
      t.bigint :campaign_id, null: false
      t.bigint :uploaded_by_id, null: false
      # Metadata cached from the validated blob so lists never need to touch storage.
      t.string :filename, null: false
      t.string :content_type, null: false
      t.bigint :byte_size, null: false
      t.integer :width, null: false
      t.integer :height, null: false
      t.string :checksum
      t.string :alt_text, limit: 1000
      t.timestamps
    end

    add_index :glint_reach_assets, [:account_id, :campaign_id]
    add_index :glint_reach_assets, [:campaign_id, :created_at]
    add_foreign_key :glint_reach_assets, :glint_reach_campaigns, column: :campaign_id, on_delete: :cascade
  end
end
