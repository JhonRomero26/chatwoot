# frozen_string_literal: true

# Enforces the conversation "assignment self-lock":
#
# Once an agent holds a conversation (self-assigned or auto-assigned), they
# cannot unassign it to nil/blank themselves, and cannot hand it to an
# arbitrary/invalid target. They CAN release it to another valid agent
# (inbox member or administrator), and resolving/closing is a separate
# concern handled elsewhere (not gated by this policy).
#
# Privileged agents (administrators and `conversation_manage` permission
# holders) and agent bots are exempt and behave exactly as before.
module Custom::ConversationAssignmentPolicy
  module_function

  # user:            the acting User (or AgentBot) making the change
  # account_user:    the acting AccountUser row for this account (nil for bots)
  # conversation:    the Conversation being reassigned
  # new_assignee_id: the target assignee id from the request (nil/blank/'0' clears it)
  # new_assignee_type: 'User' (default) or 'AgentBot'
  def can_change_assignee?(user:, account_user:, conversation:, new_assignee_id:, new_assignee_type: 'User')
    return true if Custom::VisibilityConcern.privileged?(account_user)
    return true if user.is_a?(AgentBot)

    if currently_held_by?(conversation, user)
      change_from_own_conversation_allowed?(conversation, user, new_assignee_id, new_assignee_type)
    else
      change_from_unheld_conversation_allowed?(user, new_assignee_id)
    end
  end

  # --- private helpers (module_function makes these callable the same way) ---

  def currently_held_by?(conversation, user)
    conversation.assignee_id.present? && user.present? && conversation.assignee_id == user.id
  end
  private_class_method :currently_held_by?

  def blank_assignee?(new_assignee_id)
    new_assignee_id.blank? || new_assignee_id.to_s == '0' || new_assignee_id.to_s.casecmp('nil').zero?
  end
  private_class_method :blank_assignee?

  # Agent currently holds the conversation: they may release it to a valid
  # agent, or reassign to themselves (no-op), but cannot clear it to nil.
  def change_from_own_conversation_allowed?(conversation, user, new_assignee_id, new_assignee_type)
    return false if blank_assignee?(new_assignee_id)
    return true if new_assignee_id.to_s == user.id.to_s

    valid_target?(conversation, new_assignee_id, new_assignee_type)
  end
  private_class_method :change_from_own_conversation_allowed?

  # Agent does not currently hold the conversation: they can always clear an
  # unassigned/foreign chat they don't hold, or pick it up for themselves,
  # but cannot hand someone else's (or an unassigned) chat to a third party.
  def change_from_unheld_conversation_allowed?(user, new_assignee_id)
    return true if blank_assignee?(new_assignee_id)

    new_assignee_id.to_s == user.id.to_s
  end
  private_class_method :change_from_unheld_conversation_allowed?

  def valid_target?(conversation, new_assignee_id, new_assignee_type)
    account = conversation.account

    if new_assignee_type.to_s == 'AgentBot'
      AgentBot.accessible_to(account).exists?(id: new_assignee_id)
    else
      conversation.inbox.members.exists?(id: new_assignee_id) || account.administrators.exists?(id: new_assignee_id)
    end
  end
  private_class_method :valid_target?
end
