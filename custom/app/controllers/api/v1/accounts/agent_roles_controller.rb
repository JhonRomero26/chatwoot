# frozen_string_literal: true

class Api::V1::Accounts::AgentRolesController < Api::V1::Accounts::BaseController
  before_action :fetch_agent_role, only: [:show, :update, :destroy]
  before_action :check_authorization

  def index
    @agent_roles = Current.account.agent_roles.order(:name)
  end

  def show; end

  def create
    @agent_role = Current.account.agent_roles.create!(permitted_params)
  end

  def update
    @agent_role.update!(permitted_params)
  end

  def destroy
    @agent_role.destroy!
    head :ok
  end

  private

  def check_authorization
    super(AgentRole)
  end

  def fetch_agent_role
    @agent_role = Current.account.agent_roles.find(params[:id])
  end

  def permitted_params
    params.require(:agent_role).permit(:name, permissions: [])
  end
end
