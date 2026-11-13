class CreateGlintReachVariantAssets < ActiveRecord::Migration[7.2]
  def change
    create_table :glint_reach_variant_assets do |t|
      t.bigint :content_variant_id, null: false
      t.bigint :asset_id, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :glint_reach_variant_assets, [:content_variant_id, :asset_id], unique: true
    add_index :glint_reach_variant_assets, :asset_id
    add_foreign_key :glint_reach_variant_assets, :glint_reach_content_variants, column: :content_variant_id, on_delete: :cascade
    add_foreign_key :glint_reach_variant_assets, :glint_reach_assets, column: :asset_id, on_delete: :cascade
  end
end
