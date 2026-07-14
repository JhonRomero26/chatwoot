# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Agent roles API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:agent_role) { create(:agent_role, account: account, name: 'Supervisor', permissions: %w[conversation_manage report_manage]) }

  describe 'GET /api/v1/accounts/:account_id/agent_roles' do
    it 'returns agent roles for administrators' do
      get "/api/v1/accounts/#{account.id}/agent_roles", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to contain_exactly(include('id' => agent_role.id, 'name' => 'Supervisor', 'permissions' => %w[conversation_manage report_manage]))
    end

    it 'forbids agents' do
      get "/api/v1/accounts/#{account.id}/agent_roles", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /api/v1/accounts/:account_id/agent_roles' do
    it 'creates an empty-permission role' do
      post "/api/v1/accounts/#{account.id}/agent_roles",
           headers: admin.create_new_auth_token,
           params: { agent_role: { name: 'Observer', permissions: [] } },
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('name' => 'Observer', 'permissions' => [])
    end

    it 'rejects unsupported permissions' do
      post "/api/v1/accounts/#{account.id}/agent_roles",
           headers: admin.create_new_auth_token,
           params: { agent_role: { name: 'Broken', permissions: ['unsupported_permission'] } },
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH /api/v1/accounts/:account_id/agent_roles/:id' do
    it 'updates the role' do
      patch "/api/v1/accounts/#{account.id}/agent_roles/#{agent_role.id}",
            headers: admin.create_new_auth_token,
            params: { agent_role: { permissions: ['report_manage'] } },
            as: :json

      expect(response).to have_http_status(:success)
      expect(agent_role.reload.permissions).to eq(['report_manage'])
    end
  end

  describe 'DELETE /api/v1/accounts/:account_id/agent_roles/:id' do
    it 'nullifies assigned users' do
      assigned_agent = create(:user, account: account, role: :agent)
      assigned_account_user = assigned_agent.account_users.find_by!(account: account)
      assigned_account_user.update!(agent_role: agent_role)

      delete "/api/v1/accounts/#{account.id}/agent_roles/#{agent_role.id}", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      expect(assigned_account_user.reload.agent_role_id).to be_nil
    end
  end
end
