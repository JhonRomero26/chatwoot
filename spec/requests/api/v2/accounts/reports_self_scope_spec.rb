require 'rails_helper'

RSpec.describe 'Reports self scope', type: :request do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:manager) { create(:user, account: account, role: :agent) }
  let(:report_manager) { create(:user, account: account, role: :agent) }
  let(:conversation_manager) { create(:user, account: account, role: :agent) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }
  let(:manager_role) { create(:agent_role, account: account, permissions: %w[conversation_manage report_manage]) }
  let(:report_manager_role) { create(:agent_role, account: account, permissions: ['report_manage']) }
  let(:conversation_manager_role) { create(:agent_role, account: account, permissions: ['conversation_manage']) }
  let(:since) { 2.days.ago.beginning_of_day.to_i.to_s }
  let(:until_time) { Time.current.end_of_day }
  let(:until_param) { until_time.to_i.to_s }

  before do
    create(:inbox_member, inbox: inbox, user: manager)
    create(:inbox_member, inbox: inbox, user: report_manager)
    create(:inbox_member, inbox: inbox, user: conversation_manager)
    create(:inbox_member, inbox: inbox, user: agent)
    create(:inbox_member, inbox: inbox, user: other_agent)
    manager.account_users.find_by(account: account).update!(agent_role: manager_role)
    report_manager.account_users.find_by(account: account).update!(agent_role: report_manager_role)
    conversation_manager.account_users.find_by(account: account).update!(agent_role: conversation_manager_role)

    create_list(:conversation, 2, account: account, inbox: inbox, assignee: agent, created_at: 1.day.ago)
    create(:conversation, account: account, inbox: inbox, assignee: other_agent, created_at: 1.day.ago)

    create(:message, account: account, inbox: inbox, conversation: agent.assigned_conversations.first, sender: agent,
                     message_type: :outgoing, created_at: 1.day.ago)
    create(:message, account: account, inbox: inbox, conversation: other_agent.assigned_conversations.first, sender: other_agent,
                     message_type: :outgoing, created_at: 1.day.ago)
  end

  it 'returns only the current agent counts for summary and outgoing messages' do
    get "/api/v2/accounts/#{account.id}/reports/summary",
        params: { type: :account, since: since, until: until_param, timezone_offset: 0 },
        headers: agent.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['conversations_count']).to eq(2)

    get "/api/v2/accounts/#{account.id}/reports/outgoing_messages_count",
        params: { group_by: 'agent', since: since, until: until_param },
        headers: agent.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to contain_exactly(include('id' => agent.id, 'outgoing_messages_count' => 1))
  end

  it 'returns only the current agent row for conversations and agents csv' do
    get "/api/v2/accounts/#{account.id}/reports/conversations",
        params: { type: :agent },
        headers: agent.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.pluck('id')).to eq([agent.id])

    get "/api/v2/accounts/#{account.id}/reports/agents.csv",
        params: { since: since, until: until_param },
        headers: agent.create_new_auth_token

    expect(response).to have_http_status(:success)
    expect(response.body).to include(agent.name)
    expect(response.body).not_to include(other_agent.name)
  end

  it 'keeps admin and report managers with report access account wide' do
    [admin, manager, report_manager].each do |user|
      get "/api/v2/accounts/#{account.id}/reports/summary",
          params: { type: :account, since: since, until: until_param, timezone_offset: 0 },
          headers: user.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['conversations_count']).to eq(3)
    end
  end

  it 'permits report-capable managers drilldown' do
    get "/api/v2/accounts/#{account.id}/reports/drilldown",
        params: {
          metric: 'conversations_count',
          type: :account,
          since: since,
          until: until_param,
          bucket_timestamp: until_time.beginning_of_day.to_i.to_s,
          group_by: 'day'
        },
        headers: manager.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['meta']['total_count']).to eq(3)
  end

  it 'keeps conversation-only managers self-scoped for reports' do
    get "/api/v2/accounts/#{account.id}/reports/summary",
        params: { type: :account, since: since, until: until_param, timezone_offset: 0 },
        headers: conversation_manager.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['conversations_count']).to eq(0)
  end
end
