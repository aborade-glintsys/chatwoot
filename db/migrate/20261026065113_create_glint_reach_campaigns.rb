class CreateGlintReachCampaigns < ActiveRecord::Migration[7.2]
  def change
    create_table :glint_reach_campaigns do |t|
      t.bigint :account_id, null: false
      t.bigint :created_by_id, null: false
      t.string :name, null: false
      t.integer :objective, null: false
      t.text :brief
      t.text :target_audience
      t.integer :status, null: false, default: 0
      t.datetime :starts_at
      t.datetime :ends_at
      t.timestamps
    end

    add_index :glint_reach_campaigns, [:account_id, :status]
    add_index :glint_reach_campaigns, :created_by_id
  end
end
