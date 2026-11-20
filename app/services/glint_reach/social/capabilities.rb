# Immutable capability description for a provider and account type.
# Returned by the API so the UI never offers unsupported post types, formats or actions.
GlintReach::Social::Capabilities = Data.define(
  :post_types,
  :max_text_length,
  :max_images,
  :image_mime_types,
  :supports_video,
  :supports_scheduling_natively,
  :supports_refresh,
  :token_lifetime_days
) do
  def to_h
    {
      post_types: post_types,
      max_text_length: max_text_length,
      max_images: max_images,
      image_mime_types: image_mime_types,
      supports_video: supports_video,
      supports_scheduling_natively: supports_scheduling_natively,
      supports_refresh: supports_refresh,
      token_lifetime_days: token_lifetime_days
    }
  end
end
