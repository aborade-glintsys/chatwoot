module GlintReach::Lifecycle
  extend ActiveSupport::Concern

  # Including models define TRANSITIONS: { from_status => [allowed to_statuses] }.
  def transition_to!(new_status)
    new_status = new_status.to_s
    unless self.class::TRANSITIONS.fetch(status, []).include?(new_status)
      errors.add(:status, :invalid_transition, from: status, to: new_status)
      raise ActiveRecord::RecordInvalid, self
    end

    update!(status: new_status)
  end
end
