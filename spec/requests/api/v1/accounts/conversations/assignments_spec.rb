# frozen_string_literal: true

require 'rails_helper'

# Request specs for the assignment self-lock overlay on
# Api::V1::Accounts::Conversations::AssignmentsController. The base controller
# routes through Conversations::AssignmentService; the custom overlay (see
# custom/app/controllers/custom/api/v1/accounts/conversations/assignments_controller.rb)
# raises CustomExceptions::Conversation::AssignmentLocked before delegating
# to super when the policy blocks the change.
RSpec.describe 'Conversation Assignment API (self-lock overlay)', type: :request do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }
  let(:admin) { create(:user, account: account, role: :administrator) }

  before do
    create(:inbox_member, user: agent, inbox: inbox)
    create(:inbox_member, user: other_agent, inbox: inbox)
  end

  def post_assignment(assignee_id:, headers:)
    post api_v1_account_conversation_assignments_url(account_id: account.id, conversation_id: conversation.display_id),
         params: { assignee_id: assignee_id },
         headers: headers,
         as: :json
  end

  context 'when a non-privileged agent who holds the conversation tries to unassign' do
    before { conversation.update!(assignee: agent) }

    it 'returns 403 with error_code ASSIGNMENT_LOCKED' do
      post_assignment(assignee_id: nil, headers: agent.create_new_auth_token)

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body).to include('error_code' => 'ASSIGNMENT_LOCKED')
    end
  end

  context 'when a non-privileged agent who holds the conversation self-assigns (idempotent)' do
    before { conversation.update!(assignee: agent) }

    it 'returns 200' do
      post_assignment(assignee_id: agent.id, headers: agent.create_new_auth_token)

      expect(response).to have_http_status(:success)
      expect(conversation.reload.assignee_id).to eq(agent.id)
    end
  end

  context 'when a non-privileged agent who holds the conversation releases to a teammate' do
    before { conversation.update!(assignee: agent) }

    it 'returns 200' do
      post_assignment(assignee_id: other_agent.id, headers: agent.create_new_auth_token)

      expect(response).to have_http_status(:success)
      expect(conversation.reload.assignee_id).to eq(other_agent.id)
    end
  end

  context 'when a non-privileged agent who does NOT hold the conversation tries to reassign it to a third party' do
    # The agent can only see the conversation if it's unassigned or assigned to
    # them, so this mirrors the manual runner case where the agent is staring
    # at an unassigned chat and tries to hand it to a teammate instead of
    # picking it up themselves.
    let(:third_party) { create(:user, account: account, role: :agent) }

    before do
      create(:inbox_member, user: third_party, inbox: inbox)
      conversation.update!(assignee: nil)
    end

    it 'returns 403 with error_code ASSIGNMENT_LOCKED' do
      post_assignment(assignee_id: third_party.id, headers: agent.create_new_auth_token)

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body).to include('error_code' => 'ASSIGNMENT_LOCKED')
      expect(conversation.reload.assignee_id).to be_nil
    end
  end

  context 'when an administrator unassigns any conversation' do
    before { conversation.update!(assignee: agent) }

    it 'returns 200' do
      post_assignment(assignee_id: nil, headers: admin.create_new_auth_token)

      expect(response).to have_http_status(:success)
      expect(conversation.reload.assignee_id).to be_nil
    end
  end
end
