json.payload @generations do |generation|
  json.partial! 'api/v1/models/glint_reach/generation', formats: [:json], generation: generation
end
