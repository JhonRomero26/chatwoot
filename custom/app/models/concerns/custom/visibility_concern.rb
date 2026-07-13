# frozen_string_literal: true

module Custom::VisibilityConcern
  module_function

  def privileged?(account_user)
    account_user&.privileged?
  end

  def privileged_account_users(account)
    administrators = account.account_users.where(role: AccountUser.roles[:administrator])
    administrators.or(account.account_users.where(supervisor: true))
  end

  def visible_conversations(scope, account_user)
    return scope.none if account_user.blank?
    return scope if privileged?(account_user)

    scope.where(inbox: account_user.user.inboxes.where(account_id: account_user.account_id))
         .where(assignee_id: [nil, account_user.user_id])
  end
end
