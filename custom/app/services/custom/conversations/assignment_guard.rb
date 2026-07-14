# frozen_string_literal: true

# Applies the conversation assignment self-lock to ActionService, the
# service backing macros (Macros::ExecutionService < ActionService) and any
# other direct caller. Prepended onto ActionService explicitly (see
# custom/config/initializers/assignment_lock_overlays.rb) rather than via the
# `include_mod_with` hook at the bottom of action_service.rb, since `include`
# can't override methods already defined directly on ActionService and this
# guard must run before the real assignment logic.
#
# System/automation contexts (no signed-in Current.user, e.g. automation
# rules) are not a human "self-lock" scenario and are left untouched.
module Custom::Conversations::AssignmentGuard
  def assign_agent(agent_ids = [])
    return super if Current.user.blank?

    target_id = agent_ids[0] == 'nil' ? nil : agent_ids[0]
    # 'last_responding_agent' resolves to a real id inside the base
    # implementation; resolve it here too so the guard checks the real target.
    target_id = last_responding_agent_id if agent_ids[0] == 'last_responding_agent'

    raise CustomExceptions::Conversation::AssignmentLocked.new({}) unless assignment_allowed?(target_id)

    super
  end

  def remove_assigned_agent(params)
    return super if Current.user.blank?

    raise CustomExceptions::Conversation::AssignmentLocked.new({}) unless assignment_allowed?(nil)

    super
  end

  private

  def assignment_allowed?(new_assignee_id)
    return true if Current.user.is_a?(AgentBot)

    Custom::ConversationAssignmentPolicy.can_change_assignee?(
      user: Current.user,
      account_user: @account.account_users.find_by(user_id: Current.user.id),
      conversation: @conversation,
      new_assignee_id: new_assignee_id
    )
  end
end
