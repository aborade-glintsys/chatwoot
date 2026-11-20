# Provider-neutral error hierarchy for social OAuth and account management.
class GlintReach::Social::Error < StandardError
  def code = self.class.name.demodulize.underscore
end
