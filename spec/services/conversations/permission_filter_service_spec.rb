require 'rails_helper'

RSpec.describe Conversations::PermissionFilterService do
  let(:account) { create(:account) }
  let!(:assigned_to_agent) { create(:conversation, account: account, inbox: inbox, assignee: agent) }
  let!(:unassigned_conversation) { create(:conversation, account: account, inbox: inbox, assignee: nil) }
  let!(:assigned_to_other_agent) { create(:conversation, account: account, inbox: inbox, assignee: other_agent) }
  let!(:other_inbox_conversation) { create(:conversation, account: account, inbox: other_inbox, assignee: nil) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }
  let(:conversation_manager) { create(:user, account: account, role: :agent) }
  let(:report_manager) { create(:user, account: account, role: :agent) }
  let(:conversation_manager_role) { create(:agent_role, account: account, permissions: ['conversation_manage']) }
  let(:report_manager_role) { create(:agent_role, account: account, permissions: ['report_manage']) }
  let!(:inbox) { create(:inbox, account: account) }
  let!(:other_inbox) { create(:inbox, account: account) }

  # This inbox_member is used to establish the agent's access to the inbox
  before do
    create(:inbox_member, user: agent, inbox: inbox)
    create(:inbox_member, user: conversation_manager, inbox: inbox)
    create(:inbox_member, user: report_manager, inbox: inbox)
    conversation_manager.account_users.find_by(account: account).update!(agent_role: conversation_manager_role)
    report_manager.account_users.find_by(account: account).update!(agent_role: report_manager_role)
  end

  describe '#perform' do
    context 'when user is an administrator' do
      it 'returns all conversations' do
        result = described_class.new(
          account.conversations,
          admin,
          account
        ).perform

        expect(result).to contain_exactly(
          assigned_to_agent,
          unassigned_conversation,
          assigned_to_other_agent,
          other_inbox_conversation
        )
      end
    end

    context 'when user is an agent' do
      it 'returns only own assigned and unassigned conversations from accessible inboxes' do
        result = described_class.new(
          account.conversations,
          agent,
          account
        ).perform

        expect(result).to contain_exactly(assigned_to_agent, unassigned_conversation)
      end
    end

    context 'when user has conversation_manage permission' do
      it 'returns all conversations' do
        result = described_class.new(
          account.conversations,
          conversation_manager,
          account
        ).perform

        expect(result).to contain_exactly(
          assigned_to_agent,
          unassigned_conversation,
          assigned_to_other_agent,
          other_inbox_conversation
        )
      end
    end

    context 'when user only has report_manage permission' do
      it 'does not get privileged conversation visibility' do
        result = described_class.new(
          account.conversations,
          report_manager,
          account
        ).perform

        expect(result).to contain_exactly(unassigned_conversation)
      end
    end

    context 'when user has an enterprise custom role' do
      before do
        create(:conversation_participant, account: account, conversation: assigned_to_other_agent, user: agent)
        agent.account_users.find_by(account: account).update!(
          custom_role: create(:custom_role, account: account, permissions: ['conversation_participating_manage'])
        )
      end

      it 'preserves enterprise participant filtering semantics' do
        result = described_class.new(
          account.conversations,
          agent,
          account
        ).perform

        expect(result).to contain_exactly(assigned_to_agent, assigned_to_other_agent)
      end
    end
  end
end
