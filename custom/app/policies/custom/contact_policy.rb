# frozen_string_literal: true

module Custom::ContactPolicy
  def export?
    agent_role_contact_manage? || super
  end

  def import?
    agent_role_contact_manage? || super
  end

  private

  def agent_role_contact_manage?
    return false if account_user&.custom_role_id.present?

    account_user&.agent_role&.permissions&.include?('contact_manage') || false
  end
end
