json.payload @approvals do |approval|
  json.partial! 'api/v1/models/glint_reach/approval', formats: [:json], approval: approval
end
