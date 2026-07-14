# frozen_string_literal: true

module Custom::ArticlePolicy
  def index?
    agent_role_knowledge_base_manage? || super
  end

  def show?
    agent_role_knowledge_base_manage? || super
  end

  def edit?
    agent_role_knowledge_base_manage? || super
  end

  def update?
    agent_role_knowledge_base_manage? || super
  end

  def create?
    agent_role_knowledge_base_manage? || super
  end

  def destroy?
    agent_role_knowledge_base_manage? || super
  end

  def reorder?
    agent_role_knowledge_base_manage? || super
  end

  private

  def agent_role_knowledge_base_manage?
    return false if account_user&.custom_role_id.present?

    account_user&.agent_role&.permissions&.include?('knowledge_base_manage') || false
  end
end
