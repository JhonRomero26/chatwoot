# frozen_string_literal: true

# Extends the assignment self-lock to BulkActionsJob, the async path used by
# the right-click "Assign agent" / "Unassign" context menu
# (POST /api/v1/accounts/:id/bulk_actions). Without this overlay an agent
# could bypass the AssignmentsController guard by going through bulk actions:
# the job calls `conversation.update(assignee_id: ...)` directly, never
# touching ActionService#assign_agent.
#
# Prepended explicitly (see custom/config/initializers/assignment_lock_overlays.rb)
# because BulkActionsJob has no `include_mod_with` hook and we need to
# intercept the per-conversation update loop.
#
# Blocked conversations are dropped from the batch and the rest of the update
# is delegated to the base implementation. Dropped conversations are logged
# so the audit trail is preserved.
module Custom::Conversations::BulkAssignmentGuard
  def bulk_conversation_update
    return super unless bulk_assignee_change?

    original = @records
    @records = original.select { |c| bulk_assignment_allowed?(c) }
    blocked = original - @records

    blocked.each do |c|
      Rails.logger.info(
        "[BulkAssignmentGuard] Skipping conversation=#{c.id} for user=#{@user.id} " \
        "target=#{bulk_target_assignee_id.inspect} (locked by policy)"
      )
    end

    return if @records.empty?

    super
  ensure
    @records = original if defined?(original) && original
  end

  private

  def bulk_assignee_change?
    fields = @params[:fields]
    return false unless fields.respond_to?(:key?)

    fields.key?(:assignee_id) || fields.key?('assignee_id')
  end

  def bulk_target_assignee_id
    raw = @params[:fields][:assignee_id]
    return nil if raw.blank? || raw.to_s == '0' || raw.to_s.casecmp('nil').zero?

    raw
  end

  def bulk_assignment_allowed?(conversation)
    au = @account.account_users.find_by(user_id: @user.id)
    Custom::ConversationAssignmentPolicy.can_change_assignee?(
      user: @user,
      account_user: au,
      conversation: conversation,
      new_assignee_id: bulk_target_assignee_id
    )
  end
end
