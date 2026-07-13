# frozen_string_literal: true

module Custom::ConversationPolicy
  def show?
    return super if account_user&.custom_role_id.present?

    return true if Custom::VisibilityConcern.privileged?(account_user) || agent_bot?

    Conversation.visible_to_account_user(account_user).exists?(id: record.id)
  end
end
