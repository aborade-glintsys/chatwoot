# URLs are short-lived signed paths generated per authorized request; they are never stored.
json.id asset.id
json.campaign_id asset.campaign_id
json.filename asset.filename
json.content_type asset.content_type
json.byte_size asset.byte_size
json.width asset.width
json.height asset.height
json.alt_text asset.alt_text
json.url asset.url
json.thumbnail_url asset.thumbnail_url
json.url_expires_in GlintReach::Asset::URL_EXPIRY.to_i
json.uploaded_by_id asset.uploaded_by_id
json.created_at asset.created_at.to_i
json.updated_at asset.updated_at.to_i
