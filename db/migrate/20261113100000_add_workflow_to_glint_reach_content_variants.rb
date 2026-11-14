# Phase 06 workflow. Status integers are reused: 0 stays draft and the former `ready` (1) becomes
# `in_review`, so existing "ready" variants need a real approval and nothing is inferred.
class AddWorkflowToGlintReachContentVariants < ActiveRecord::Migration[7.2]
  def change
    add_column :glint_reach_content_variants, :lock_version, :integer, null: false, default: 0
    add_column :glint_reach_content_variants, :submitted_by_id, :bigint
    add_column :glint_reach_content_variants, :submitted_at, :datetime
  end
end
