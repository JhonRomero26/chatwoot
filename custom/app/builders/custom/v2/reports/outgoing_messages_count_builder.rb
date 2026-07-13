# frozen_string_literal: true

module Custom::V2::Reports::OutgoingMessagesCountBuilder
  private

  def base_messages
    Custom::Reports::AccessControl.filter_messages(super, Current.account_user)
  end

  def build_by_agent
    rows = super
    return rows unless Custom::Reports::AccessControl.self_scoped?(Current.account_user)

    rows.select { |row| row[:id] == Current.account_user.user_id }
  end
end
