# frozen_string_literal: true

module Custom::V2::Reports::DrilldownBuilder
  private

  def message_scope
    Custom::Reports::AccessControl.filter_messages(super, Current.account_user)
  end

  def conversation_scope
    Custom::Reports::AccessControl.filter_conversations(super, Current.account_user)
  end

  def reporting_event_scope
    Custom::Reports::AccessControl.filter_reporting_events(super, Current.account_user)
  end
end
