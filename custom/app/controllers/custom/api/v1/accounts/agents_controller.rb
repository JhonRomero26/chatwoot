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
        AgentAvailabilitySchedule.where(account_user: target_account_user).delete_all
        permitted_schedule_rows.each do |row|
          AgentAvailabilitySchedule.create!(row.merge(account_user: target_account_user))
        end
      end
    end

    @schedule_rows = weekly_schedule_rows
    render :availability_schedule if request.put?
  end

  def create
    super
    sync_supervisor!(@agent.current_account_user, new_agent_params)
  end

  def update
    super
    sync_supervisor!(@agent.current_account_user, agent_params)
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
    super + [:supervisor]
  end

  def allowed_agent_params
    super + [:supervisor]
  end

  def new_agent_params
    params.require(:agent).permit(:email, :name, :role, :availability, :auto_offline, :supervisor)
  end

  def sync_supervisor!(account_user, permitted_params)
    return if account_user.blank?

    role = permitted_params[:role].presence || account_user.role
    supervisor_param_present = permitted_params.key?(:supervisor) || permitted_params.key?('supervisor')
    return account_user.update!(supervisor: false) if role == 'administrator'
    return unless supervisor_param_present

    supervisor = ActiveModel::Type::Boolean.new.cast(permitted_params[:supervisor])
    account_user.update!(supervisor: supervisor)
  end

  def schedule_action?
    action_name == 'availability_schedule'
  end

  def can_manage_availability_schedule?
    Current.account_user.administrator? || Current.account_user.supervisor?
  end

  def target_account_user
    @target_account_user ||= Current.account.account_users.find_by!(user_id: @agent.id)
  end

  def weekly_schedule_rows
    rows = AgentAvailabilitySchedule.where(account_user: target_account_user).index_by(&:day_of_week)

    (0..6).map do |day_of_week|
      rows[day_of_week] || AgentAvailabilitySchedule.new(account_user: target_account_user, day_of_week: day_of_week, timezone: default_schedule_timezone)
    end
  end

  def default_schedule_timezone
    target_account_user.account.reporting_timezone.presence || 'UTC'
  end

  def permitted_schedule_rows
    params.require(:weekly_schedule).map do |row|
      row.permit(
        :day_of_week,
        :timezone,
        :morning_start_minutes,
        :morning_end_minutes,
        :afternoon_start_minutes,
        :afternoon_end_minutes
      ).to_h
    end
  end
end
