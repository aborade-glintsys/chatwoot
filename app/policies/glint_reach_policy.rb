class GlintReachPolicy < ApplicationPolicy
  def show?
    @account_user&.administrator? || false
  end
end
