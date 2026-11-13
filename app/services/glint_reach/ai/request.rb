# What the campaign layer asks of any AI provider.
#   system_prompt: trusted instructions written by GlintReach.
#   user_content:  untrusted data blocks (brand profile, brief, user instruction) – never instructions.
#   schema:        Schematist schema class describing the required JSON output.
GlintReach::Ai::Request = Data.define(:system_prompt, :user_content, :schema, :feature) do
  def initialize(system_prompt:, user_content:, schema:, feature: GlintReach::Ai::ProviderResolver::FEATURE)
    super
  end

  def json_schema
    schema.new.to_json_schema
  end
end
