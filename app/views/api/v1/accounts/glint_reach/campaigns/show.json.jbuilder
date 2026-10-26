json.partial! 'api/v1/models/glint_reach/campaign', formats: [:json], campaign: @campaign
json.content_items @campaign.content_items do |content_item|
  json.partial! 'api/v1/models/glint_reach/content_item', formats: [:json], content_item: content_item
end
