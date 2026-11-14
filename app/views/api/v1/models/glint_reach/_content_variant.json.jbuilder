json.id variant.id
json.content_item_id variant.content_item_id
json.platform variant.platform
json.body variant.body
json.call_to_action variant.call_to_action
json.hashtags variant.hashtags
json.status variant.status
json.generation_id variant.generation_id
json.asset_ids variant.assets.map(&:id)
json.assets variant.assets do |asset|
  json.id asset.id
  json.alt_text asset.alt_text
  json.thumbnail_url asset.thumbnail_url
end
json.lock_version variant.lock_version
json.editable variant.editable?
json.submitted_by_id variant.submitted_by_id
json.submitted_at variant.submitted_at&.to_i
json.permissions GlintReach::Workflow.new(variant: variant, user: Current.user).permissions if Current.user
json.latest_approval do
  if variant.latest_approval
    json.partial! 'api/v1/models/glint_reach/approval', formats: [:json], approval: variant.latest_approval
  else
    json.nil!
  end
end
json.schedule do
  schedule = variant.latest_schedule if %w[scheduled publishing published failed].include?(variant.status)
  if schedule
    json.partial! 'api/v1/models/glint_reach/schedule', formats: [:json], schedule: schedule
  else
    json.nil!
  end
end
json.created_at variant.created_at.to_i
json.updated_at variant.updated_at.to_i
