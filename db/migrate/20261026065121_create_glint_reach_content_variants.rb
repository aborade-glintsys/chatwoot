class CreateGlintReachContentVariants < ActiveRecord::Migration[7.2]
  def change
    create_table :glint_reach_content_variants do |t|
      t.bigint :account_id, null: false
      t.references :content_item, null: false, index: false, foreign_key: { to_table: :glint_reach_content_items, on_delete: :cascade }
      t.integer :platform, null: false
      t.text :body
      t.string :call_to_action
      t.string :hashtags, array: true, null: false, default: []
      t.integer :status, null: false, default: 0
      t.timestamps
    end

    add_index :glint_reach_content_variants, [:content_item_id, :platform], unique: true
    add_index :glint_reach_content_variants, :account_id
  end
end
