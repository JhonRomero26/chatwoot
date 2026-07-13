require 'rails_helper'

RSpec.describe ConversationPolicy, type: :policy do
  subject { described_class }

  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:conversation_manager) { create(:user, account: account, role: :agent) }
  let(:report_manager) { create(:user, account: account, role: :agent) }
  let(:conversation_manager_role) { create(:agent_role, account: account, permissions: ['conversation_manage']) }
  let(:report_manager_role) { create(:agent_role, account: account, permissions: ['report_manage']) }
  let(:administrator_context) { { user: administrator, account: account, account_user: administrator.account_users.find_by(account: account) } }
  let(:agent_context) { { user: agent, account: account, account_user: agent.account_users.find_by(account: account) } }
  let(:conversation_manager_context) { { user: conversation_manager, account: account, account_user: conversation_manager.account_users.find_by(account: account) } }
  let(:report_manager_context) { { user: report_manager, account: account, account_user: report_manager.account_users.find_by(account: account) } }

  let(:conversation) { create(:conversation, account: account) }

  before do
    conversation_manager.account_users.find_by(account: account).update!(agent_role: conversation_manager_role)
    report_manager.account_users.find_by(account: account).update!(agent_role: report_manager_role)
  end

  permissions :destroy? do
    context 'when user is an administrator' do
      it 'allows destroy' do
        expect(subject).to permit(administrator_context, conversation)
      end
    end

    context 'when user is an agent' do
      it 'denies destroy' do
        expect(subject).not_to permit(agent_context, conversation)
      end
    end
  end

  permissions :index? do
    context 'when user is authenticated' do
      it 'allows index' do
        expect(subject).to permit(agent_context, conversation)
      end
    end
  end

  permissions :show? do
    context 'when user is an administrator' do
      it 'allows access' do
        expect(subject).to permit(administrator_context, conversation)
      end
    end

    context 'when agent has inbox access' do
      let(:inbox) { create(:inbox, account: account) }
      let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: nil) }

      before { create(:inbox_member, user: agent, inbox: inbox) }

      it 'allows access' do
        expect(subject).to permit(agent_context, conversation)
      end
    end

    context 'when agent is assigned the conversation' do
      let(:inbox) { create(:inbox, account: account) }
      let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: agent) }

      before { create(:inbox_member, user: agent, inbox: inbox) }

      it 'allows access' do
        expect(subject).to permit(agent_context, conversation)
      end
    end

    context 'when conversation is assigned to another agent' do
      let(:inbox) { create(:inbox, account: account) }
      let(:other_agent) { create(:user, account: account, role: :agent) }
      let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: other_agent) }

      before { create(:inbox_member, user: agent, inbox: inbox) }

      it 'denies access' do
        expect(subject).not_to permit(agent_context, conversation)
      end
    end

    context 'when user has conversation_manage permission' do
      let(:inbox) { create(:inbox, account: account) }
      let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: create(:user, account: account, role: :agent)) }

      it 'allows access' do
        expect(subject).to permit(conversation_manager_context, conversation)
      end
    end

    context 'when user only has report_manage permission' do
      let(:inbox) { create(:inbox, account: account) }
      let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: create(:user, account: account, role: :agent)) }

      it 'denies access' do
        expect(subject).not_to permit(report_manager_context, conversation)
      end
    end

    context 'when agent has an enterprise custom role' do
      let(:inbox) { create(:inbox, account: account) }
      let(:other_agent) { create(:user, account: account, role: :agent) }
      let(:custom_role) { create(:custom_role, account: account, permissions: ['conversation_participating_manage']) }
      let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: other_agent) }

      before do
        create(:inbox_member, user: agent, inbox: inbox)
        agent.account_users.find_by(account: account).update!(custom_role: custom_role)
        create(:conversation_participant, conversation: conversation, account: account, user: agent)
      end

      it 'delegates to inherited custom role permissions' do
        expect(subject).to permit(agent_context, conversation)
      end
    end
  end
end
