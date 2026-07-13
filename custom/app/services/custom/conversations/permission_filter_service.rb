# frozen_string_literal: true

module Custom::Conversations::PermissionFilterService
  def perform
    return super if account_user&.custom_role_id.present?

    return conversations if Custom::VisibilityConcern.privileged?(account_user)

    super.merge(Conversation.visible_to_account_user(account_user))
  end
end
