json.payload @schedules do |schedule|
  variant = schedule.content_variant
  item = variant.content_item
  json.partial! 'api/v1/models/glint_reach/schedule', formats: [:json], schedule: schedule
  json.variant do
    json.id variant.id
    json.platform variant.platform
    json.status variant.status
    json.excerpt variant.body.to_s.truncate(140)
  end
  json.content_item do
    json.id item.id
    json.title item.title
  end
  json.campaign do
    json.id item.campaign.id
    json.name item.campaign.name
  end
end
