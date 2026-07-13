module Enterprise::Api::V1::Accounts::AgentsController
  def create
    super
    associate_agent_with_custom_role
  end

  def update
    super
    associate_agent_with_custom_role
  end

  private

  def associate_agent_with_custom_role
    custom_role_id = params[:custom_role_id]
    attrs = { custom_role_id: custom_role_id }
    # agent_role and custom_role are mutually exclusive privilege sources.
    attrs[:agent_role_id] = nil if custom_role_id.present?
    @agent.current_account_user.update!(attrs)
  end
end
