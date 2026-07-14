# frozen_string_literal: true

module Custom::Api::V1::Accounts::Conversations::AssignmentsController
  def self.prepended(base)
    base.rescue_from CustomExceptions::Conversation::AssignmentLocked, with: :render_assignment_locked
  end

  def create
    authorize_assignee_change! if params.key?(:assignee_id) || agent_bot_assignment?

    super
  end

  private

  def authorize_assignee_change!
    allowed = Custom::ConversationAssignmentPolicy.can_change_assignee?(
      user: Current.user,
      account_user: Current.account_user,
      conversation: @conversation,
      new_assignee_id: params[:assignee_id],
      new_assignee_type: params[:assignee_type].presence || 'User'
    )

    raise CustomExceptions::Conversation::AssignmentLocked.new({}) unless allowed
  end

  def render_assignment_locked(exception)
    render json: exception.to_hash, status: exception.http_status
  end
end
