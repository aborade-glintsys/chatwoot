json.meta do
  json.count @count
  json.current_page @current_page
end
json.payload @variants do |variant|
  json.partial! 'api/v1/models/glint_reach/content_variant', formats: [:json], variant: variant
  json.submitted_by do
    json.id variant.submitted_by_id
    json.name variant.submitted_by&.name
  end
  json.content_item do
    json.id variant.content_item.id
    json.title variant.content_item.title
  end
  json.campaign do
    json.id variant.content_item.campaign.id
    json.name variant.content_item.campaign.name
  end
end
