# frozen_string_literal: true

module Custom::ConversationPolicy
  def show?
    return super if account_user&.custom_role_id.present?

    return true if Custom::VisibilityConcern.privileged?(account_user) || agent_bot?
    return true if agent_role_permits_unassigned_manage?
    return true if agent_role_permits_participating?

    Conversation.visible_to_account_user(account_user).exists?(id: record.id)
  end

  private

  # NOTE: named `agent_role_*` (not `permits_*`) to avoid shadowing
  # Enterprise::ConversationPolicy's own private methods of the same short
  # name — both modules are prepended onto the same ConversationPolicy
  # instance, so identical method names collide across the ancestor chain
  # regardless of module namespace.
  def agent_role_permits_unassigned_manage?
    return false unless agent_role_permissions.include?('conversation_unassigned_manage')

    record.assignee_id.nil? || assigned_to_user?
  end

  def agent_role_permits_participating?
    return false unless agent_role_permissions.include?('conversation_participating_manage')

    assigned_to_user? || participant?
  end

  def agent_role_permissions
    account_user&.agent_role&.permissions || []
  end
end
