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
json.created_at variant.created_at.to_i
json.updated_at variant.updated_at.to_i
