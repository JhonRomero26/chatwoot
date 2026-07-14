# frozen_string_literal: true

module Custom::Conversations::PermissionFilterService
  def perform
    return super if account_user&.custom_role_id.present?

    return conversations if Custom::VisibilityConcern.privileged?(account_user)
    return agent_role_tiered_scope if agent_role_permissions.intersect?(TIERED_PERMISSIONS)

    super.merge(Conversation.visible_to_account_user(account_user))
  end

  private

  TIERED_PERMISSIONS = %w[conversation_unassigned_manage conversation_participating_manage].freeze

  def agent_role_permissions
    account_user&.agent_role&.permissions || []
  end

  # NOTE: named `agent_role_*` (not `filter_*`) to avoid shadowing
  # Enterprise::Conversations::PermissionFilterService's own private methods
  # of the same short name — both modules are prepended onto the same
  # service instance, so identical method names collide across the
  # ancestor chain regardless of module namespace.
  #
  # Unions every granted tier instead of first-match-wins, so this scope
  # stays consistent with ConversationPolicy#show?, which OR-checks each
  # tier independently rather than picking only the first matching one.
  def agent_role_tiered_scope
    scope = accessible_conversations.none

    scope = scope.or(accessible_conversations.where(assignee_id: [nil, user.id])) if agent_role_permissions.include?('conversation_unassigned_manage')

    scope = scope.or(agent_role_participating_scope) if agent_role_permissions.include?('conversation_participating_manage')

    scope
  end

  def agent_role_participating_scope
    participant_conversation_ids = ConversationParticipant.where(account_id: account.id, user_id: user.id).select(:conversation_id)

    accessible_conversations
      .where(assignee_id: user.id)
      .or(accessible_conversations.where(id: participant_conversation_ids))
  end
end
