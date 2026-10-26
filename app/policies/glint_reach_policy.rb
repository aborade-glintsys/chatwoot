class GlintReachPolicy < ApplicationPolicy
  def show?
    @account_user.administrator?
  end
end
