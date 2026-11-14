if @brand_profile&.persisted?
  json.brand_profile do
    json.partial! 'api/v1/models/glint_reach/brand_profile', formats: [:json], brand_profile: @brand_profile
  end
else
  json.brand_profile nil
end
