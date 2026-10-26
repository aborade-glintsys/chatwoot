json.id content_item.id
json.campaign_id content_item.campaign_id
json.title content_item.title
json.content_type content_item.content_type
json.status content_item.status
json.variants content_item.variants do |variant|
  json.partial! 'api/v1/models/glint_reach/content_variant', formats: [:json], variant: variant
end
json.created_at content_item.created_at.to_i
json.updated_at content_item.updated_at.to_i
