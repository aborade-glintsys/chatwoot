# Provider-neutral result.
#   payload: Hash parsed from the model's JSON output (validated by the caller against the schema).
#   usage:   { input_tokens:, output_tokens:, credit_multiplier: } – any value may be nil.
GlintReach::Ai::Response = Data.define(:payload, :provider, :model, :usage)
