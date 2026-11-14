class AddBriefFieldsToGlintReachCampaigns < ActiveRecord::Migration[7.2]
  def change
    change_table :glint_reach_campaigns, bulk: true do |t|
      t.text :offer
      t.text :key_message
      t.string :desired_action
      t.string :channels, array: true, null: false, default: []
    end
  end
end
