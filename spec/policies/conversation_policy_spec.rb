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
  let(:conversation_manager_context) do
    { user: conversation_manager, account: account, account_user: conversation_manager.account_users.find_by(account: account) }
  end
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

    context 'when agent has conversation_unassigned_manage agent_role permission' do
      let(:unassigned_manager) { create(:user, account: account, role: :agent) }

      before do
        role = create(:agent_role, account: account, permissions: ['conversation_unassigned_manage'])
        unassigned_manager.account_users.find_by(account: account).update!(agent_role: role)
      end

      def unassigned_manager_context(unassigned_manager)
        { user: unassigned_manager, account: account, account_user: unassigned_manager.account_users.find_by(account: account) }
      end

      it 'allows access to an unassigned conversation' do
        conversation = create(:conversation, account: account, assignee: nil)

        expect(subject).to permit(unassigned_manager_context(unassigned_manager), conversation)
      end

      it 'allows access to a conversation assigned to self' do
        conversation = create(:conversation, account: account, assignee: unassigned_manager)

        expect(subject).to permit(unassigned_manager_context(unassigned_manager), conversation)
      end

      it 'denies access to a conversation assigned to another agent' do
        conversation = create(:conversation, account: account, assignee: create(:user, account: account, role: :agent))

        expect(subject).not_to permit(unassigned_manager_context(unassigned_manager), conversation)
      end
    end

    context 'when agent has conversation_participating_manage agent_role permission' do
      let(:participating_manager) { create(:user, account: account, role: :agent) }

      before do
        role = create(:agent_role, account: account, permissions: ['conversation_participating_manage'])
        participating_manager.account_users.find_by(account: account).update!(agent_role: role)
      end

      def participating_manager_context(participating_manager)
        { user: participating_manager, account: account, account_user: participating_manager.account_users.find_by(account: account) }
      end

      it 'allows access to a conversation assigned to self' do
        conversation = create(:conversation, account: account, assignee: participating_manager)

        expect(subject).to permit(participating_manager_context(participating_manager), conversation)
      end

      it 'allows access to a conversation where the agent is a participant' do
        inbox = create(:inbox, account: account)
        create(:inbox_member, user: participating_manager, inbox: inbox)
        conversation = create(:conversation, account: account, inbox: inbox, assignee: create(:user, account: account, role: :agent))
        create(:conversation_participant, conversation: conversation, account: account, user: participating_manager)

        expect(subject).to permit(participating_manager_context(participating_manager), conversation)
      end

      it 'denies access to an unrelated conversation' do
        conversation = create(:conversation, account: account, assignee: create(:user, account: account, role: :agent))

        expect(subject).not_to permit(participating_manager_context(participating_manager), conversation)
      end
    end
  end
end
