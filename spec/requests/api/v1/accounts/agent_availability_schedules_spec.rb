# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Agent availability schedules', type: :request do
  let(:account) { create(:account, reporting_timezone: 'America/New_York') }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:conversation_manager) { create(:user, account: account, role: :agent) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:target_agent) { create(:user, account: account, role: :agent, name: 'Target Agent') }
  let(:target_account_user) { target_agent.account_users.find_by!(account: account) }
  let(:conversation_manager_role) { create(:agent_role, account: account, permissions: ['conversation_manage']) }
  let(:path) { "/api/v1/accounts/#{account.id}/agents/#{target_agent.id}/availability_schedule" }

  before do
    conversation_manager.account_users.find_by!(account: account).update!(agent_role: conversation_manager_role)
    create(:agent_availability_schedule,
           account_user: target_account_user,
           day_of_week: 1,
           start_minutes: 540,
           end_minutes: 720,
           timezone: 'America/New_York')
  end

  describe 'GET /api/v1/accounts/:account_id/agents/:id/availability_schedule' do
    it 'returns the weekly schedule for admins and conversation managers' do
      get path, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['agent_id']).to eq(target_agent.id)
      expect(response.parsed_body['timezone']).to eq('America/New_York')
      expect(response.parsed_body['weekly_schedule'].size).to eq(7)
      expect(response.parsed_body['weekly_schedule'][1]).to include(
        'day_of_week' => 1
      )
      expect(response.parsed_body['weekly_schedule'][1]['ranges']).to contain_exactly(
        include('start_minutes' => 540, 'end_minutes' => 720)
      )

      get path, headers: conversation_manager.create_new_auth_token, as: :json
      expect(response).to have_http_status(:success)
    end

    it 'forbids ordinary agents' do
      get path, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PUT /api/v1/accounts/:account_id/agents/:id/availability_schedule' do
    it 'replaces the weekly rows and returns the updated schedule' do
      put path,
          params: {
            timezone: 'UTC',
            weekly_schedule: [
              { day_of_week: 2, ranges: [{ start_minutes: 600, end_minutes: 660 }] },
              { day_of_week: 4, ranges: [{ start_minutes: 780, end_minutes: 900 }] }
            ]
          },
          headers: conversation_manager.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(AgentAvailabilitySchedule.where(account_user: target_account_user).pluck(:day_of_week)).to match_array([2, 4])
      expect(AgentAvailabilitySchedule.where(account_user: target_account_user).pluck(:timezone).uniq).to eq(['UTC'])
      expect(response.parsed_body['weekly_schedule'][2]).to include(
        'day_of_week' => 2
      )
      expect(response.parsed_body['weekly_schedule'][2]['ranges']).to contain_exactly(
        include('start_minutes' => 600, 'end_minutes' => 660)
      )
    end

    it 'returns validation errors for invalid ranges' do
      put path,
          params: { timezone: 'UTC', weekly_schedule: [{ day_of_week: 3, ranges: [{ start_minutes: 600 }] }] },
          headers: admin.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(AgentAvailabilitySchedule.where(account_user: target_account_user).pluck(:day_of_week)).to eq([1])
    end
  end

  describe 'DELETE /api/v1/accounts/:account_id/agents/:id' do
    it 'deletes an agent that has an availability schedule' do
      expect(AgentAvailabilitySchedule.where(account_user: target_account_user)).to exist

      delete "/api/v1/accounts/#{account.id}/agents/#{target_agent.id}",
             headers: admin.create_new_auth_token,
             as: :json

      expect(response).to have_http_status(:success)
      expect(AgentAvailabilitySchedule.where(account_user_id: target_account_user.id)).not_to exist
    end
  end
end
