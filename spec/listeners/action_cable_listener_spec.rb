require 'rails_helper'
describe ActionCableListener do
  let(:listener) { described_class.instance }
  let!(:account) { create(:account) }
  let!(:admin) { create(:user, account: account, role: :administrator) }
  let!(:inbox) { create(:inbox, account: account) }
  let!(:agent) { create(:user, account: account, role: :agent) }
  let!(:supervisor) { create(:user, account: account, role: :agent) }
  let!(:other_agent) { create(:user, account: account, role: :agent) }
  let!(:conversation_manager_role) { create(:agent_role, account: account, permissions: ['conversation_manage']) }
  let!(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: agent) }

  before do
    create(:inbox_member, inbox: inbox, user: agent)
    create(:inbox_member, inbox: inbox, user: supervisor)
    create(:inbox_member, inbox: inbox, user: other_agent)
    supervisor.account_users.find_by(account: account).update!(agent_role: conversation_manager_role)
    Current.user = nil
    Current.account = nil
  end

  describe '#account_cache_invalidated' do
    let!(:event) do
      Events::Base.new(
        :'account.cache_invalidated',
        Time.zone.now,
        account: account,
        cache_keys: account.cache_keys
      )
    end

    it 'sends cache invalidation to account agents and admins' do
      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        a_collection_containing_exactly(
          agent.pubsub_token,
          other_agent.pubsub_token,
          supervisor.pubsub_token,
          admin.pubsub_token
        ),
        'account.cache_invalidated',
        {
          cache_keys: account.cache_keys,
          account_id: account.id
        }
      )

      listener.account_cache_invalidated(event)
    end
  end

  describe '#message_created' do
    let(:event_name) { :'message.created' }
    let!(:message) do
      create(:message, message_type: 'outgoing',
                       account: account, inbox: inbox, conversation: conversation)
    end
    let!(:event) { Events::Base.new(event_name, Time.zone.now, message: message) }

    it 'sends message to account admins, inbox agents and the contact' do
      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        a_collection_containing_exactly(
          agent.pubsub_token,
          admin.pubsub_token,
          supervisor.pubsub_token,
          conversation.contact_inbox.pubsub_token
        ),
        'message.created',
        message.push_event_data.merge(account_id: account.id)
      )
      listener.message_created(event)
    end

    it 'sends message to all hmac verified contact inboxes' do
      conversation.contact_inbox.update(hmac_verified: true)
      # creating a non verified contact inbox to ensure the events are not sent to it
      create(:contact_inbox, contact: conversation.contact, inbox: inbox)
      verified_contact_inbox = create(:contact_inbox, contact: conversation.contact, inbox: inbox, hmac_verified: true)

      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        a_collection_containing_exactly(
          agent.pubsub_token,
          admin.pubsub_token,
          supervisor.pubsub_token,
          conversation.contact_inbox.pubsub_token,
          verified_contact_inbox.pubsub_token
        ),
        'message.created',
        message.push_event_data.merge(account_id: account.id)
      )
      listener.message_created(event)
    end
  end

  describe '#typing_on' do
    let(:event_name) { :'conversation.typing_on' }
    let!(:event) { Events::Base.new(event_name, Time.zone.now, conversation: conversation, user: agent, is_private: false) }

    it 'sends message to account admins, inbox agents and the contact' do
      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        a_collection_containing_exactly(
          admin.pubsub_token, supervisor.pubsub_token, conversation.contact_inbox.pubsub_token
        ),
        'conversation.typing_on', { conversation: conversation.push_event_data,
                                    user: agent.push_event_data,
                                    account_id: account.id,
                                    is_private: false }
      )
      listener.conversation_typing_on(event)
    end
  end

  describe '#typing_on with contact' do
    let(:event_name) { :'conversation.typing_on' }
    let!(:event) { Events::Base.new(event_name, Time.zone.now, conversation: conversation, user: conversation.contact, is_private: false) }

    it 'sends message to account admins, inbox agents and the contact' do
      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        a_collection_containing_exactly(
          admin.pubsub_token, supervisor.pubsub_token, agent.pubsub_token
        ),
        'conversation.typing_on', { conversation: conversation.push_event_data,
                                    user: conversation.contact.push_event_data,
                                    account_id: account.id,
                                    is_private: false }
      )
      listener.conversation_typing_on(event)
    end
  end

  describe '#typing_on with agent bot' do
    let(:event_name) { :'conversation.typing_on' }
    let!(:agent_bot) { create(:agent_bot, account: account) }
    let!(:event) { Events::Base.new(event_name, Time.zone.now, conversation: conversation, user: agent_bot, is_private: false) }

    it 'sends message to account admins, inbox agents and the contact' do
      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        a_collection_containing_exactly(
          admin.pubsub_token,
          supervisor.pubsub_token,
          agent.pubsub_token,
          conversation.contact_inbox.pubsub_token
        ),
        'conversation.typing_on', { conversation: conversation.push_event_data,
                                    user: agent_bot.push_event_data,
                                    account_id: account.id,
                                    is_private: false }
      )
      listener.conversation_typing_on(event)
    end
  end

  describe '#typing_off' do
    let(:event_name) { :'conversation.typing_off' }
    let!(:event) { Events::Base.new(event_name, Time.zone.now, conversation: conversation, user: agent, is_private: false) }

    it 'sends message to account admins, inbox agents and the contact' do
      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        a_collection_containing_exactly(
          admin.pubsub_token, supervisor.pubsub_token, conversation.contact_inbox.pubsub_token
        ),
        'conversation.typing_off', { conversation: conversation.push_event_data,
                                     user: agent.push_event_data,
                                     account_id: account.id,
                                     is_private: false }
      )
      listener.conversation_typing_off(event)
    end
  end

  describe '#contact_deleted' do
    let(:event_name) { :'contact.deleted' }
    let!(:contact) { create(:contact, account: account) }
    let(:contact_data) { contact.push_event_data.merge(account_id: contact.account_id) }
    let!(:event) { Events::Base.new(event_name, Time.zone.now, contact_data: contact_data) }

    it 'sends message to account admins, inbox agents' do
      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        ["account_#{account.id}"],
        'contact.deleted',
        contact_data
      )
      listener.contact_deleted(event)
    end
  end

  describe '#notification_deleted' do
    let(:event_name) { :'notification.deleted' }
    let!(:notification) { create(:notification, account: account, user: agent) }
    let(:notification_data) do
      {
        id: notification.id,
        user_id: agent.id,
        account_id: account.id
      }
    end
    let!(:event) { Events::Base.new(event_name, Time.zone.now, notification_data: notification_data) }

    it 'sends message to account admins, inbox agents' do
      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        [agent.pubsub_token],
        'notification.deleted',
        {
          account_id: notification.account_id,
          notification: {
            id: notification.id
          },
          unread_count: 1,
          count: 1
        }
      )

      listener.notification_deleted(event)
    end
  end

  describe '#notification_updated' do
    let(:event_name) { :'notification.updated' }
    let!(:notification) { create(:notification, account: account, user: agent) }
    let!(:event) { Events::Base.new(event_name, Time.zone.now, notification: notification) }

    it 'sends notification to account admins, inbox agents' do
      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        [agent.pubsub_token],
        'notification.updated',
        {
          account_id: notification.account_id,
          notification: notification.push_event_data,
          unread_count: 1,
          count: 1
        }
      )

      listener.notification_updated(event)
    end
  end

  describe '#conversation_updated' do
    let(:event_name) { :'conversation.updated' }
    let!(:event) { Events::Base.new(event_name, Time.zone.now, conversation: conversation, user: agent, is_private: false) }

    before do
      conversation.add_labels(['support'])
    end

    it 'sends update to inbox members' do
      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        a_collection_containing_exactly(
          agent.pubsub_token,
          admin.pubsub_token,
          supervisor.pubsub_token,
          conversation.contact_inbox.pubsub_token
        ),
        'conversation.updated',
        conversation.push_event_data.merge(account_id: account.id)
      )
      listener.conversation_updated(event)
    end

    it 'broadcast event with label data' do
      expect(conversation.reload.push_event_data[:labels]).to eq(conversation.labels.pluck(:name))

      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        a_collection_containing_exactly(
          agent.pubsub_token,
          admin.pubsub_token,
          supervisor.pubsub_token,
          conversation.contact_inbox.pubsub_token
        ),
        'conversation.updated',
        conversation.push_event_data.merge(account_id: account.id)
      )
      listener.conversation_updated(event)
    end
  end

  describe '#conversation_unread_count_changed' do
    let(:event_name) { :'conversation.unread_count_changed' }
    let!(:agent_without_inbox_access) { create(:user, account: account, role: :agent) }
    let!(:event) { Events::Base.new(event_name, Time.zone.now, conversation: conversation) }

    before do
      account.enable_features!(:conversation_unread_counts)
    end

    it 'sends a lightweight refresh event to inbox agents and admins' do
      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        a_collection_containing_exactly(agent.pubsub_token, admin.pubsub_token, supervisor.pubsub_token),
        'conversation.unread_count_changed',
        {
          account_id: account.id
        }
      )

      listener.conversation_unread_count_changed(event)
    end

    it 'does not broadcast unread count refresh to agents outside the inbox' do
      expect(ActionCableBroadcastJob).not_to receive(:perform_later).with(
        array_including(agent_without_inbox_access.pubsub_token),
        anything,
        anything
      )

      listener.conversation_unread_count_changed(event)
    end

    it 'does not broadcast when conversation unread counts feature is disabled' do
      account.disable_features!(:conversation_unread_counts)

      expect(ActionCableBroadcastJob).not_to receive(:perform_later)

      listener.conversation_unread_count_changed(event)
    end

    it 'supports deleted conversation data' do
      event = Events::Base.new(
        event_name,
        Time.zone.now,
        conversation_data: {
          id: conversation.id,
          account_id: account.id,
          inbox_id: conversation.inbox_id
        }
      )

      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        a_collection_containing_exactly(agent.pubsub_token, admin.pubsub_token, supervisor.pubsub_token),
        'conversation.unread_count_changed',
        {
          account_id: account.id
        }
      )

      listener.conversation_unread_count_changed(event)
    end
  end

  describe 'A1b realtime visibility filtering' do
    let(:assigned_payload) { conversation.push_event_data.merge(account_id: account.id) }

    def build_custom_role_user(permissions)
      user = create(:user, account: account, role: :agent)
      create(:inbox_member, inbox: inbox, user: user)
      user.account_users.find_by(account: account).update!(custom_role: create(:custom_role, account: account, permissions: permissions))
      user
    end

    def removal_payload(conversation_id)
      { id: conversation_id, remove_from_agent_view: true, account_id: account.id }
    end

    it 'hides assigned conversations from non-assignees but keeps unassigned conversations visible' do
      unassigned_conversation = create(:conversation, account: account, inbox: inbox, assignee: nil)

      aggregate_failures do
        expect(ActionCableBroadcastJob).to receive(:perform_later).with(
          a_collection_containing_exactly(agent.pubsub_token, admin.pubsub_token, supervisor.pubsub_token, conversation.contact_inbox.pubsub_token),
          'conversation.updated',
          assigned_payload
        )
        listener.conversation_updated(Events::Base.new(:'conversation.updated', Time.zone.now, conversation: conversation))

        expect(ActionCableBroadcastJob).to receive(:perform_later).with(
          a_collection_containing_exactly(agent.pubsub_token, other_agent.pubsub_token, supervisor.pubsub_token, admin.pubsub_token,
                                          unassigned_conversation.contact_inbox.pubsub_token),
          'conversation.created',
          unassigned_conversation.push_event_data.merge(account_id: account.id)
        )
        listener.conversation_created(Events::Base.new(:'conversation.created', Time.zone.now, conversation: unassigned_conversation))
      end
    end

    it 'delivers assigned payloads to admins, supervisors, and custom roles allowed by policy' do
      custom_role_user = build_custom_role_user(['conversation_manage'])

      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        a_collection_containing_exactly(agent.pubsub_token, admin.pubsub_token, supervisor.pubsub_token, custom_role_user.pubsub_token,
                                        conversation.contact_inbox.pubsub_token),
        'conversation.updated',
        assigned_payload
      )

      listener.conversation_updated(Events::Base.new(:'conversation.updated', Time.zone.now, conversation: conversation))
    end

    it 'keeps assigned payloads away from custom roles without permission, even when they are the assignee' do
      blocked_assignee = build_custom_role_user([])
      conversation.update!(assignee: blocked_assignee)
      event = Events::Base.new(:'assignee.changed', Time.zone.now, conversation: conversation,
                                                                   changed_attributes: { 'assignee_id' => [agent.id, blocked_assignee.id] })

      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        a_collection_containing_exactly(supervisor.pubsub_token, admin.pubsub_token),
        'assignee.changed',
        conversation.push_event_data.merge(account_id: account.id)
      ).ordered
      expect(ActionCableBroadcastJob).to receive(:perform_later).with([agent.pubsub_token], 'assignee.changed',
                                                                      removal_payload(conversation.id)).ordered

      listener.assignee_changed(event)
    end

    it 'does not include the previous assignee in removal_tokens when they retain conversation_manage via agent_role' do
      # ponytail: agents with agent_role (conversation_manage) keep visibility
      # after a reassignment. The broadcast must NOT mark them as evicted.
      event = Events::Base.new(:'assignee.changed', Time.zone.now, conversation: conversation,
                                                                   changed_attributes: { 'assignee_id' => [supervisor.id, agent.id] })

      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        a_collection_containing_exactly(agent.pubsub_token, admin.pubsub_token, supervisor.pubsub_token),
        'assignee.changed',
        conversation.push_event_data.merge(account_id: account.id)
      ).ordered
      # No removal broadcast for supervisor (the previous assignee with conversation_manage).
      expect(ActionCableBroadcastJob).not_to receive(:perform_later).with(
        a_collection_including(supervisor.pubsub_token),
        'assignee.changed',
        hash_including(remove_from_agent_view: true)
      )

      listener.assignee_changed(event)
    end

    it 'suppresses mentions when the recipient cannot view the conversation' do
      expect(ActionCableBroadcastJob).not_to receive(:perform_later)

      listener.conversation_mentioned(Events::Base.new(:'conversation.mentioned', Time.zone.now, conversation: conversation, user: other_agent))
    end

    it 'sends minimal removals to revoked agents when an unassigned conversation becomes assigned' do
      claiming_agent = create(:user, account: account, role: :agent)
      create(:inbox_member, inbox: inbox, user: claiming_agent)
      unassigned_conversation = create(:conversation, account: account, inbox: inbox, assignee: nil)
      unassigned_conversation.update!(assignee: claiming_agent)
      event = Events::Base.new(:'assignee.changed', Time.zone.now, conversation: unassigned_conversation,
                                                                   changed_attributes: { 'assignee_id' => [nil, claiming_agent.id] })

      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        a_collection_containing_exactly(claiming_agent.pubsub_token, supervisor.pubsub_token, admin.pubsub_token),
        'assignee.changed',
        unassigned_conversation.push_event_data.merge(account_id: account.id)
      ).ordered
      expect(ActionCableBroadcastJob).to receive(:perform_later).with(a_collection_containing_exactly(agent.pubsub_token, other_agent.pubsub_token),
                                                                      'assignee.changed', removal_payload(unassigned_conversation.id)).ordered

      listener.assignee_changed(event)
    end
  end
end
