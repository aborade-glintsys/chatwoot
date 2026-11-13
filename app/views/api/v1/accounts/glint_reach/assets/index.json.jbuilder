json.meta do
  json.count @assets_count
  json.current_page @current_page
end

json.payload do
  json.array! @assets do |asset|
    json.partial! 'api/v1/models/glint_reach/asset', formats: [:json], asset: asset
  end
end
