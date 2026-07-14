# frozen_string_literal: true

require 'rails_helper'

# Coverage for the assignment self-lock overlay prepended onto BulkActionsJob.
# The base job iterates each conversation and calls `conversation.update(...)`
# with the batch's params, which includes `assignee_id` when the right-click
# context menu "Assign agent" / "Unassign" action is used. Without the
# overlay, an agent could bypass the AssignmentsController guard by going
# through the bulk endpoint.
RSpec.describe BulkActionsJob do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }
  let(:admin) { create(:user, account: account, role: :administrator) }

  before do
    create(:inbox_member, user: agent, inbox: inbox)
    create(:inbox_member, user: other_agent, inbox: inbox)
  end

  def perform_bulk(assignee_id:, conversations:, acting_user: agent)
    params = { type: 'Conversation', fields: { assignee_id: assignee_id }, ids: conversations.map(&:display_id) }
    described_class.perform_now(account: account, params: params, user: acting_user)
  end

  context 'when a non-privileged agent tries to unassign a conversation they hold' do
    let(:held) { create(:conversation, account: account, inbox: inbox, assignee: agent) }

    it 'leaves the assignee unchanged' do
      perform_bulk(assignee_id: nil, conversations: [held])

      expect(held.reload.assignee_id).to eq(agent.id)
    end
  end

  context 'when a non-privileged agent self-assigns a conversation they already hold (idempotent)' do
    let(:held) { create(:conversation, account: account, inbox: inbox, assignee: agent) }

    it 'keeps the assignee' do
      perform_bulk(assignee_id: agent.id, conversations: [held])

      expect(held.reload.assignee_id).to eq(agent.id)
    end
  end

  context 'when a non-privileged agent releases a held conversation to a teammate' do
    let(:held) { create(:conversation, account: account, inbox: inbox, assignee: agent) }

    it 'reassigns to the teammate' do
      perform_bulk(assignee_id: other_agent.id, conversations: [held])

      expect(held.reload.assignee_id).to eq(other_agent.id)
    end
  end

  context 'when a non-privileged agent tries to hand an unassigned conversation to a third party' do
    let(:third_party) { create(:user, account: account, role: :agent) }
    let(:unassigned) { create(:conversation, account: account, inbox: inbox, assignee: nil) }

    before { create(:inbox_member, user: third_party, inbox: inbox) }

    it 'leaves the assignee unchanged' do
      perform_bulk(assignee_id: third_party.id, conversations: [unassigned])

      expect(unassigned.reload.assignee_id).to be_nil
    end
  end

  context 'when an administrator bulk-unassigns conversations' do
    let(:held) { create(:conversation, account: account, inbox: inbox, assignee: agent) }
    let(:other_held) { create(:conversation, account: account, inbox: inbox, assignee: other_agent) }

    it 'unassigns them all (privileged path is exempt from the lock)' do
      perform_bulk(assignee_id: nil, conversations: [held, other_held], acting_user: admin)

      expect(held.reload.assignee_id).to be_nil
      expect(other_held.reload.assignee_id).to be_nil
    end
  end

  context 'when a non-privileged agent mixes allowed and blocked conversations' do
    let(:held) { create(:conversation, account: account, inbox: inbox, assignee: agent) }
    let(:unassigned) { create(:conversation, account: account, inbox: inbox, assignee: nil) }

    it 'skips the blocked conversation and applies the allowed one' do
      # Held chat: agent can't unassign it. Unassigned chat: agent can pick it
      # up. Same batch, different per-conversation outcomes.
      perform_bulk(assignee_id: nil, conversations: [held, unassigned], acting_user: agent)

      expect(held.reload.assignee_id).to eq(agent.id)
      expect(unassigned.reload.assignee_id).to be_nil
    end
  end
end
