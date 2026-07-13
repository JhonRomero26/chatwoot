# frozen_string_literal: true

module Custom::Api::V2::Accounts::ReportsController
  SELF_SCOPED_ACTIONS = %w[index summary agents conversations_summary conversation_traffic conversations outgoing_messages_count drilldown].freeze

  def agents
    return super unless self_scoped_reports?

    report = V2::Reports::AgentSummaryBuilder.new(account: Current.account, params: csv_report_params(type: :agent)).build.find do |row|
      row[:id] == Current.account_user.user_id
    end

    @report_data = [[Current.user.name] + generate_readable_report_metrics(report || {})]
    generate_csv('agents_report', 'api/v2/accounts/reports/agents')
  end

  def drilldown
    return super if account_wide_reports?
    return head :unprocessable_entity unless valid_drilldown_params?

    render json: V2::Reports::DrilldownBuilder.new(Current.account, drilldown_params.merge(type: :account, id: nil)).build
  end

  private

  def check_authorization
    return head :unauthorized if self_scoped_reports? && !SELF_SCOPED_ACTIONS.include?(action_name)

    super
  end

  def common_params
    scope_agent_params(super)
  end

  def conversation_params
    params = super
    return params unless self_scoped_reports? && params[:type].to_sym == :agent

    params.merge(user_id: Current.account_user.user_id)
  end

  def csv_report_params(type:)
    {
      type: type,
      since: params[:since],
      until: params[:until],
      business_hours: ActiveModel::Type::Boolean.new.cast(params[:business_hours])
    }
  end

  def scope_agent_params(report_params)
    return report_params unless self_scoped_reports?
    return report_params unless report_params[:type].to_sym == :agent

    report_params.merge(id: Current.account_user.user_id)
  end

  def account_wide_reports?
    Custom::Reports::AccessControl.account_wide?(Current.account_user)
  end

  def self_scoped_reports?
    Custom::Reports::AccessControl.self_scoped?(Current.account_user)
  end
end
