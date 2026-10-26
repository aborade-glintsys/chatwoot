class CreateGlintReachContentItems < ActiveRecord::Migration[7.2]
  def change
    create_table :glint_reach_content_items do |t|
      t.bigint :account_id, null: false
      t.references :campaign, null: false, index: false, foreign_key: { to_table: :glint_reach_campaigns, on_delete: :cascade }
      t.string :title, null: false
      t.integer :content_type, null: false
      t.integer :status, null: false, default: 0
      t.timestamps
    end

    add_index :glint_reach_content_items, [:campaign_id, :status]
    add_index :glint_reach_content_items, :account_id
  end
end
