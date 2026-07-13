# frozen_string_literal: true

module Custom::Reports::AccessControl
  module_function

  def account_wide?(account_user)
    return false if account_user.blank?

    Custom::VisibilityConcern.privileged?(account_user) || report_manage?(account_user)
  end

  def self_scoped?(account_user)
    account_user.present? && !account_wide?(account_user)
  end

  def filter_conversations(scope, account_user)
    return scope unless self_scoped?(account_user)

    scope.where(assignee_id: account_user.user_id)
  end

  def filter_messages(scope, account_user)
    return scope unless self_scoped?(account_user)

    scope.joins(:conversation).where(conversations: { assignee_id: account_user.user_id })
  end

  def filter_reporting_events(scope, account_user)
    return scope unless self_scoped?(account_user)

    scope.joins(:conversation).where(conversations: { assignee_id: account_user.user_id })
  end

  def report_manage?(account_user)
    account_user.respond_to?(:report_manage?) && account_user.report_manage?
  end
end
