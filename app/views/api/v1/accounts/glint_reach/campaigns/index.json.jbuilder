json.meta do
  json.count @campaigns_count
  json.current_page @current_page
end

json.payload do
  json.array! @campaigns do |campaign|
    json.partial! 'api/v1/models/glint_reach/campaign', formats: [:json], campaign: campaign
  end
end
