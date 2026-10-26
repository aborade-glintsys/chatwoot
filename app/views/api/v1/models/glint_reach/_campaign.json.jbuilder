json.id campaign.id
json.account_id campaign.account_id
json.name campaign.name
json.objective campaign.objective
json.brief campaign.brief
json.target_audience campaign.target_audience
json.status campaign.status
json.starts_at campaign.starts_at&.to_i
json.ends_at campaign.ends_at&.to_i
json.created_by do
  json.id campaign.created_by.id
  json.name campaign.created_by.name
end
json.created_at campaign.created_at.to_i
json.updated_at campaign.updated_at.to_i
