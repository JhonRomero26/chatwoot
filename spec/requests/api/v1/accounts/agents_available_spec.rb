# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Available agents', type: :request do
  let(:account) { create(:account) }
  let(:requester) { create(:user, account: account, role: :agent) }
  let(:available_agent) { create(:user, account: account, role: :agent, name: 'Available Agent') }
  let(:offline_agent) { create(:user, account: account, role: :agent, name: 'Offline Agent') }
  let(:unscheduled_agent) { create(:user, account: account, role: :agent, name: 'Unscheduled Agent') }

  before do
    available_account_user = available_agent.account_users.find_by(account: account)
    offline_account_user = offline_agent.account_users.find_by(account: account)

    available_account_user.update!(auto_offline: false, availability: :busy)
    offline_account_user.update!(auto_offline: false, availability: :online)

    create(:agent_availability_schedule,
           account_user: available_account_user,
           day_of_week: 1,
           start_minutes: 540,
           end_minutes: 720)

    create(:agent_availability_schedule,
           account_user: offline_account_user,
           day_of_week: 1,
           start_minutes: 780,
           end_minutes: 1020)
  end

  it 'returns only currently available account agents with minimal fields' do
    travel_to Time.zone.parse('2026-07-13 10:00:00 UTC') do
      get "/api/v1/accounts/#{account.id}/agents/available",
          headers: requester.create_new_auth_token,
          as: :json
    end

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to eq([
                                         {
                                           'id' => available_agent.id,
                                           'name' => 'Available Agent',
                                           'availability_status' => 'busy'
                                         }
                                       ])
    expect(response.parsed_body.to_json).not_to include(unscheduled_agent.name)
  end

  it 'requires authentication' do
    get "/api/v1/accounts/#{account.id}/agents/available", as: :json

    expect(response).to have_http_status(:unauthorized)
  end
end
