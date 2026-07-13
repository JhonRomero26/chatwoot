# frozen_string_literal: true

module Custom::V2::ReportBuilder
  private

  def conversations
    Custom::Reports::AccessControl.filter_conversations(super, Current.account_user)
  end

  def incoming_messages
    Custom::Reports::AccessControl.filter_messages(super, Current.account_user)
  end

  def outgoing_messages
    Custom::Reports::AccessControl.filter_messages(super, Current.account_user)
  end

  def resolutions
    Custom::Reports::AccessControl.filter_reporting_events(super, Current.account_user)
  end

  def bot_resolutions
    Custom::Reports::AccessControl.filter_reporting_events(super, Current.account_user)
  end

  def bot_handoffs
    Custom::Reports::AccessControl.filter_reporting_events(super, Current.account_user)
  end

  def avg_first_response_time
    grouped_reporting_events = get_grouped_values(filtered_reporting_events('first_response'))
    return grouped_reporting_events.average(:value_in_business_hours) if params[:business_hours]

    grouped_reporting_events.average(:value)
  end

  def reply_time
    grouped_reporting_events = get_grouped_values(filtered_reporting_events('reply_time'))
    return grouped_reporting_events.average(:value_in_business_hours) if params[:business_hours]

    grouped_reporting_events.average(:value)
  end

  def avg_resolution_time
    grouped_reporting_events = get_grouped_values(filtered_reporting_events('conversation_resolved'))
    return grouped_reporting_events.average(:value_in_business_hours) if params[:business_hours]

    grouped_reporting_events.average(:value)
  end

  def avg_resolution_time_summary = filtered_reporting_average('conversation_resolved')

  def reply_time_summary = filtered_reporting_average('reply_time')

  def avg_first_response_time_summary = filtered_reporting_average('first_response')

  def agent_metrics
    return super unless Custom::Reports::AccessControl.self_scoped?(Current.account_user)

    @user = Current.user
    [{
      id: @user.id,
      name: @user.name,
      email: @user.email,
      thumbnail: @user.avatar_url,
      availability: Current.account_user.availability_status,
      metric: live_conversations
    }]
  end

  def filtered_reporting_events(name)
    scope = scope.reporting_events.where(name: name, account_id: account.id, created_at: range)
    Custom::Reports::AccessControl.filter_reporting_events(scope, Current.account_user)
  end

  def filtered_reporting_average(name)
    avg = filtered_reporting_events(name).average(params[:business_hours] ? :value_in_business_hours : :value)
    avg.presence || 0
  end
end
