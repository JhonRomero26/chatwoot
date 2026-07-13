# frozen_string_literal: true

module Custom::VisibilityConcern
  module_function

  def privileged?(account_user)
    account_user&.privileged?
  end

  def privileged_account_users(account)
    account.account_users
           .left_outer_joins(:agent_role)
           .where(
             'account_users.role = :administrator_role OR :conversation_manage = ANY(agent_roles.permissions)',
             administrator_role: AccountUser.roles[:administrator],
             conversation_manage: 'conversation_manage'
           )
  end

  def visible_conversations(scope, account_user)
    return scope.none if account_user.blank?
    return scope if privileged?(account_user)

    scope.where(inbox: account_user.user.inboxes.where(account_id: account_user.account_id))
         .where(assignee_id: [nil, account_user.user_id])
  end
end
