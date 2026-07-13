# frozen_string_literal: true

module Custom::Api::V1::Accounts::AgentsController
  def create
    super
    sync_supervisor!(@agent.current_account_user, new_agent_params)
  end

  def update
    super
    sync_supervisor!(@agent.current_account_user, agent_params)
  end

  private

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
end
