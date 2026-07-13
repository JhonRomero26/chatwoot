# frozen_string_literal: true

module Custom::Reports::RawDataSource
  private

  def average_scope
    scope = Custom::Reports::AccessControl.filter_reporting_events(super, Current.account_user)
    return scope unless self_scoped_agent_dimension?

    scope.where(user_id: Current.account_user.user_id)
  end

  def count_scope
    case metric.to_s
    when 'conversations_count'
      Custom::Reports::AccessControl.filter_conversations(super, Current.account_user)
    when 'incoming_messages_count', 'outgoing_messages_count'
      Custom::Reports::AccessControl.filter_messages(super, Current.account_user)
    else
      Custom::Reports::AccessControl.filter_reporting_events(super, Current.account_user)
    end
  end

  def summary_scope
    scope = Custom::Reports::AccessControl.filter_reporting_events(super, Current.account_user)
    return scope unless self_scoped_agent_dimension?

    scope.where(user_id: Current.account_user.user_id)
  end

  def summary_conversation_counts
    scope = Custom::Reports::AccessControl.filter_conversations(account.conversations.where(created_at: range), Current.account_user)
    scope.group(summary_conversation_group_by_key).count
  end

  def self_scoped_agent_dimension?
    Custom::Reports::AccessControl.self_scoped?(Current.account_user) && dimension_type == 'agent'
  end
end
