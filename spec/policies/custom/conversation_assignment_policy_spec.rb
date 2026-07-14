# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Custom::ConversationAssignmentPolicy do
  describe '.can_change_assignee?' do
    let(:account) { create(:account) }
    let(:inbox) { create(:inbox, account: account) }
    let(:conversation) { create(:conversation, account: account, inbox: inbox) }
    let(:agent) { create(:user, account: account, role: :agent) }
    let(:other_agent) { create(:user, account: account, role: :agent) }
    let(:admin) { create(:user, account: account, role: :administrator) }
    let(:outsider) { create(:user, account: account, role: :agent) }
    let(:agent_account_user) { agent.account_users.find_by(account: account) }
    let(:other_account_user) { other_agent.account_users.find_by(account: account) }
    let(:admin_account_user) { admin.account_users.find_by(account: account) }

    before do
      create(:inbox_member, user: agent, inbox: inbox)
      create(:inbox_member, user: other_agent, inbox: inbox)
    end

    context 'when user is a privileged administrator' do
      let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: agent) }

      it 'allows unassigning a conversation they hold' do
        expect(
          described_class.can_change_assignee?(
            user: admin, account_user: admin_account_user,
            conversation: conversation, new_assignee_id: nil
          )
        ).to be true
      end

      it 'allows unassigning another agent\'s conversation' do
        other_held = create(:conversation, account: account, inbox: inbox, assignee: other_agent)

        expect(
          described_class.can_change_assignee?(
            user: admin, account_user: admin_account_user,
            conversation: other_held, new_assignee_id: nil
          )
        ).to be true
      end

      it 'allows reassigning a third-party conversation to an arbitrary agent' do
        other_held = create(:conversation, account: account, inbox: inbox, assignee: other_agent)

        expect(
          described_class.can_change_assignee?(
            user: admin, account_user: admin_account_user,
            conversation: other_held, new_assignee_id: agent.id
          )
        ).to be true
      end
    end

    context 'when non-privileged agent currently holds the conversation' do
      let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: agent) }

      it 'blocks setting assignee_id to nil' do
        expect(
          described_class.can_change_assignee?(
            user: agent, account_user: agent_account_user,
            conversation: conversation, new_assignee_id: nil
          )
        ).to be false
      end

      it 'blocks the string "0" sentinel for unassign' do
        expect(
          described_class.can_change_assignee?(
            user: agent, account_user: agent_account_user,
            conversation: conversation, new_assignee_id: '0'
          )
        ).to be false
      end

      it 'blocks the string "nil" sentinel for unassign' do
        expect(
          described_class.can_change_assignee?(
            user: agent, account_user: agent_account_user,
            conversation: conversation, new_assignee_id: 'nil'
          )
        ).to be false
      end

      it 'allows releasing to a valid teammate in the same inbox' do
        expect(
          described_class.can_change_assignee?(
            user: agent, account_user: agent_account_user,
            conversation: conversation, new_assignee_id: other_agent.id
          )
        ).to be true
      end

      it 'allows releasing to an account administrator (not necessarily an inbox member)' do
        expect(
          described_class.can_change_assignee?(
            user: agent, account_user: agent_account_user,
            conversation: conversation, new_assignee_id: admin.id
          )
        ).to be true
      end

      it 'blocks releasing to a user who is not an inbox member nor an admin' do
        expect(
          described_class.can_change_assignee?(
            user: agent, account_user: agent_account_user,
            conversation: conversation, new_assignee_id: outsider.id
          )
        ).to be false
      end
    end

    context 'when non-privileged agent does NOT hold the conversation' do
      let(:unassigned) { create(:conversation, account: account, inbox: inbox, assignee: nil) }
      let(:other_held) { create(:conversation, account: account, inbox: inbox, assignee: other_agent) }

      it 'allows self-assigning an unassigned conversation' do
        expect(
          described_class.can_change_assignee?(
            user: agent, account_user: agent_account_user,
            conversation: unassigned, new_assignee_id: agent.id
          )
        ).to be true
      end

      it 'allows unassigning another agent\'s conversation' do
        expect(
          described_class.can_change_assignee?(
            user: agent, account_user: agent_account_user,
            conversation: other_held, new_assignee_id: nil
          )
        ).to be true
      end

      it 'blocks reassigning another agent\'s conversation to a third party' do
        expect(
          described_class.can_change_assignee?(
            user: agent, account_user: agent_account_user,
            conversation: other_held, new_assignee_id: outsider.id
          )
        ).to be false
      end
    end

    context 'when the agent is already the assignee and re-targets themselves (idempotent self-assign)' do
      let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: agent) }

      it 'is allowed for a non-privileged agent' do
        expect(
          described_class.can_change_assignee?(
            user: agent, account_user: agent_account_user,
            conversation: conversation, new_assignee_id: agent.id
          )
        ).to be true
      end
    end
  end
end
