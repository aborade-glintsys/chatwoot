json.id approval.id
json.decision approval.decision
json.feedback approval.feedback
json.reviewer do
  json.id approval.reviewer_id
  json.name approval.reviewer&.name
end
json.created_at approval.created_at.to_i
