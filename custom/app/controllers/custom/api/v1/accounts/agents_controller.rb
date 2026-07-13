# frozen_string_literal: true

module Custom::Api::V1::Accounts::AgentsController
  def self.prepended(base)
    base.skip_before_action :fetch_agent, only: :available
  end

  def available
    @agents = AgentAvailabilityFinder.new(Current.account).perform
  end

  def availability_schedule
    if request.put?
      ActiveRecord::Base.transaction do
        target_account_user.update!(availability_schedule_timezone: permitted_schedule_timezone)
        AgentAvailabilitySchedule.where(account_user: target_account_user).delete_all
        permitted_schedule_rows.each do |row|
          row[:ranges].each do |range|
            AgentAvailabilitySchedule.create!(
              account_user: target_account_user,
              day_of_week: row[:day_of_week],
              timezone: permitted_schedule_timezone,
              start_minutes: range[:start_minutes],
              end_minutes: range[:end_minutes]
            )
          end
        end
      end
    end

    @schedule_timezone = schedule_timezone
    @weekly_schedule = weekly_schedule_rows
    render :availability_schedule if request.put?
  end

  def create
    super
    sync_agent_role!(@agent.current_account_user, new_agent_params)
  end

  def update
    super
    sync_agent_role!(@agent.current_account_user, agent_params)
  end

  private

  def check_authorization
    return authorize(User, :index?) if action_name == 'available'

    if schedule_action?
      raise Pundit::NotAuthorizedError unless can_manage_availability_schedule?

      return
    end

    super
  end

  def account_user_attributes
    super
  end

  def allowed_agent_params
    super + [:agent_role_id]
  end

  def new_agent_params
    params.require(:agent).permit(:email, :name, :role, :availability, :auto_offline, :agent_role_id)
  end

  def sync_agent_role!(account_user, permitted_params)
    return if account_user.blank?

    role = permitted_params[:role].presence || account_user.role
    agent_role_param_present = permitted_params.key?(:agent_role_id) || permitted_params.key?('agent_role_id')
    return account_user.update!(agent_role_id: nil) if role == 'administrator'
    return unless agent_role_param_present

    new_agent_role_id = scoped_agent_role_id(permitted_params[:agent_role_id])
    attrs = { agent_role_id: new_agent_role_id }
    # agent_role and custom_role are mutually exclusive privilege sources.
    attrs[:custom_role_id] = nil if new_agent_role_id.present?
    account_user.update!(attrs)
  end

  def schedule_action?
    action_name == 'availability_schedule'
  end

  def can_manage_availability_schedule?
    Current.account_user.administrator? || Current.account_user.conversation_manage?
  end

  def target_account_user
    @target_account_user ||= Current.account.account_users.find_by!(user_id: @agent.id)
  end

  def weekly_schedule_rows
    grouped_rows = AgentAvailabilitySchedule.where(account_user: target_account_user).group_by(&:day_of_week)

    (0..6).map do |day_of_week|
      {
        day_of_week: day_of_week,
        ranges: grouped_rows.fetch(day_of_week, []).sort_by(&:start_minutes).map do |row|
          {
            start_minutes: row.start_minutes,
            end_minutes: row.end_minutes
          }
        end
      }
    end
  end

  def schedule_timezone
    target_account_user.availability_schedule_timezone.presence ||
      AgentAvailabilitySchedule.where(account_user: target_account_user).pick(:timezone) ||
      default_schedule_timezone
  end

  def permitted_schedule_rows
    params.require(:weekly_schedule).map do |row|
      permitted_row = row.permit(:day_of_week, ranges: [:start_minutes, :end_minutes]).to_h
      permitted_row[:ranges] ||= []
      permitted_row.deep_symbolize_keys
    end
  end

  def permitted_schedule_timezone
    params[:timezone].presence || default_schedule_timezone
  end

  def default_schedule_timezone
    target_account_user.account.reporting_timezone.presence || 'UTC'
  end

  def scoped_agent_role_id(agent_role_id)
    return nil if agent_role_id.blank?

    Current.account.agent_roles.find(agent_role_id).id
  end
end
