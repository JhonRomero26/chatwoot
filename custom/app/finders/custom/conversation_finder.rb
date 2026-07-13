# frozen_string_literal: true

module Custom::ConversationFinder
  private

  def filter_by_conversation_type
    return super unless params[:conversation_type] == 'participating'
    return super if current_account_user&.custom_role_id.present?

    @conversations = current_user.participating_conversations
                                 .where(account_id: current_account.id)
                                 .merge(Conversation.visible_to_account_user(current_account_user))
  end

  def current_account_user
    @current_account_user ||= current_account.account_users.find_by(user_id: current_user.id)
  end
end
