class AddGenerationFieldsToGlintReachContent < ActiveRecord::Migration[7.2]
  def change
    add_column :glint_reach_campaigns, :strategy, :jsonb
    add_column :glint_reach_content_items, :generation_id, :bigint
    add_column :glint_reach_content_variants, :generation_id, :bigint
  end
end
