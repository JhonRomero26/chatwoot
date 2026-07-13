# frozen_string_literal: true

module Custom::ActionCableListener
  include Events::Types
  def message_created(event)
    broadcast_message_event(event, MESSAGE_CREATED)
  end

  def message_updated(event)
    broadcast_message_event(event, MESSAGE_UPDATED, previous_changes: event.data[:previous_changes])
  end

  def first_reply_created(event)
    message, account = extract_message_and_account(event)
    broadcast(account, visible_member_tokens(message.conversation), FIRST_REPLY_CREATED, message.push_event_data)
  end

  def conversation_created(event)
    broadcast_conversation_event(event, CONVERSATION_CREATED, include_contact_tokens: true)
  end

  def conversation_read(event)
    broadcast_conversation_event(event, CONVERSATION_READ)
  end

  def conversation_status_changed(event)
    broadcast_conversation_event(event, CONVERSATION_STATUS_CHANGED, include_contact_tokens: true)
  end

  def conversation_updated(event)
    broadcast_conversation_event(event, CONVERSATION_UPDATED, include_contact_tokens: true)
  end

  def conversation_unread_count_changed(event)
    account = unread_count_account(event)
    return if account.blank? || !account.feature_enabled?('conversation_unread_counts')

    broadcast(account, unread_count_tokens(event, account), CONVERSATION_UNREAD_COUNT_CHANGED, {})
  end

  def conversation_typing_on(event)
    broadcast_typing_event(event, CONVERSATION_TYPING_ON)
  end

  def conversation_typing_off(event)
    broadcast_typing_event(event, CONVERSATION_TYPING_OFF)
  end

  def assignee_changed(event)
    conversation, account = extract_conversation_and_account(event)
    broadcast(account, visible_member_tokens(conversation), ASSIGNEE_CHANGED, conversation.push_event_data)

    removal_tokens = assignee_change_removal_tokens(conversation, previous_assignee_id(event))
    return if removal_tokens.blank?

    broadcast(account, removal_tokens, ASSIGNEE_CHANGED, { id: conversation.id, remove_from_agent_view: true })
  end

  def conversation_mentioned(event)
    conversation, account = extract_conversation_and_account(event)
    user = event.data[:user]

    return unless conversation_visible_to_user?(conversation, user, account)

    broadcast(account, [user.pubsub_token], CONVERSATION_MENTIONED, conversation.push_event_data)
  end

  def team_changed(event)
    broadcast_conversation_event(event, TEAM_CHANGED)
  end

  def conversation_contact_changed(event)
    broadcast_conversation_event(event, CONVERSATION_CONTACT_CHANGED)
  end

  private

  def visible_member_tokens(conversation, extra_user_id = nil)
    tokens = privileged_tokens(conversation.account)
    tokens += authorized_custom_role_member_tokens(conversation)
    tokens += inbox_member_tokens(conversation.inbox) if conversation.assignee_id.blank?
    tokens << user_token(extra_user_id) if extra_user_id.present?
    tokens << assignee_realtime_token(conversation)
    tokens.compact.uniq
  end

  def unread_count_account(event)
    event.data[:conversation]&.account || Account.find_by(id: event.data.dig(:conversation_data, :account_id))
  end

  def broadcast_message_event(event, event_name, extra_payload = {})
    message, account = extract_message_and_account(event)
    conversation = message.conversation
    tokens = visible_member_tokens(conversation) + contact_tokens(conversation.contact_inbox, message)

    broadcast(account, tokens, event_name, message.push_event_data.merge(extra_payload))
  end

  def unread_count_tokens(event, account)
    if event.data[:conversation].present?
      visible_member_tokens(event.data[:conversation])
    else
      conversation = account.conversations.find_by(id: event.data.dig(:conversation_data, :id))
      return visible_member_tokens(conversation) if conversation.present?

      inbox = account.inboxes.find_by(id: event.data.dig(:conversation_data, :inbox_id))
      assignee_id = event.data.dig(:conversation_data, :assignee_id)
      tokens = privileged_tokens(account)
      tokens += inbox_member_tokens(inbox) if assignee_id.blank?
      tokens << unread_count_assignee_token(account, event.data[:conversation_data], assignee_id) if assignee_id.present?
      tokens.compact.uniq
    end
  end

  def typing_tokens(conversation, user)
    current_user_token = if user.is_a?(Contact)
                           conversation.contact_inbox.pubsub_token
                         elsif user.respond_to?(:pubsub_token)
                           user.pubsub_token
                         end

    tokens = visible_member_tokens(conversation) + [conversation.contact_inbox.pubsub_token]
    current_user_token.present? ? tokens - [current_user_token] : tokens
  end

  def broadcast_conversation_event(event, event_name, include_contact_tokens: false)
    conversation, account = extract_conversation_and_account(event)
    tokens = visible_member_tokens(conversation)
    tokens += contact_inbox_tokens(conversation.contact_inbox) if include_contact_tokens

    broadcast(account, tokens, event_name, conversation.push_event_data)
  end

  def broadcast_typing_event(event, event_name)
    conversation = event.data[:conversation]
    user = event.data[:user]

    broadcast(conversation.account, typing_tokens(conversation, user), event_name, {
                conversation: conversation.push_event_data,
                user: user.push_event_data,
                is_private: event.data[:is_private] || false
              })
  end

  def privileged_tokens(account)
    Custom::VisibilityConcern.privileged_account_users(account).joins(:user).distinct.pluck('users.pubsub_token')
  end

  def inbox_member_tokens(inbox)
    inbox&.members&.pluck(:pubsub_token) || []
  end

  def user_token(user_id)
    User.find_by(id: user_id)&.pubsub_token
  end

  def previous_assignee_id(event)
    event.data.dig(:changed_attributes, 'assignee_id', 0) || event.data.dig(:changed_attributes, :assignee_id, 0)
  end

  def unread_count_assignee_token(account, conversation_data, assignee_id)
    account_user = account.account_users.includes(:custom_role).find_by(user_id: assignee_id)
    return user_token(assignee_id) unless account_user&.custom_role_id.present?

    conversation = account.conversations.find_by(id: conversation_data[:id] || conversation_data['id'])
    return if conversation.blank?

    assignee_realtime_token(conversation, account_user: account_user)
  end

  def assignee_change_removal_tokens(conversation, previous_assignee_id)
    return inbox_tokens_losing_visibility(conversation) if previous_assignee_id.blank? && conversation.assignee_id.present?
    if previous_assignee_id.present? && conversation.assignee_id.present?
      return previous_assignee_tokens_losing_visibility(
        conversation,
        previous_assignee_id,
        conversation.assignee_id
      )
    end

    []
  end

  def inbox_tokens_losing_visibility(conversation)
    inbox = conversation.inbox
    return [] if inbox.blank?

    retained_user_ids = privileged_user_ids(conversation.account) + authorized_custom_role_member_user_ids(conversation) + [conversation.assignee_id].compact

    inbox.members.where.not(id: retained_user_ids).pluck(:pubsub_token)
  end

  def previous_assignee_tokens_losing_visibility(conversation, previous_assignee_id, current_assignee_id)
    return [] if previous_assignee_id == current_assignee_id
    return [] if privileged_user_ids(conversation.account).include?(previous_assignee_id)
    return [] if authorized_custom_role_member_user_ids(conversation).include?(previous_assignee_id)

    [user_token(previous_assignee_id)].compact
  end

  def privileged_user_ids(account)
    Custom::VisibilityConcern.privileged_account_users(account).pluck(:user_id)
  end

  def authorized_custom_role_member_user_ids(conversation)
    authorized_custom_role_member_account_users(conversation).map(&:user_id)
  end

  def conversation_visible_to_user?(conversation, user, account, account_user = nil)
    ConversationPolicy.new(pundit_context(user, account, account_user), conversation).show?
  end

  def authorized_custom_role_member_tokens(conversation)
    authorized_custom_role_member_account_users(conversation).map { |account_user| account_user.user.pubsub_token }
  end

  def assignee_realtime_token(conversation, account_user: nil)
    assignee = conversation.assignee
    return if assignee.blank?

    account_user ||= conversation.account.account_users.includes(:custom_role).find_by(user_id: assignee.id)
    return assignee.pubsub_token unless account_user&.custom_role_id.present?
    return assignee.pubsub_token if conversation_visible_to_user?(conversation, assignee, conversation.account, account_user)
  end

  def authorized_custom_role_member_account_users(conversation)
    return [] if conversation.inbox.blank?

    conversation.account.account_users
                .where(user_id: conversation.inbox.members.select(:id))
                .where.not(custom_role_id: nil)
                .includes(:user, :custom_role)
                .select do |account_user|
      conversation_visible_to_user?(conversation, account_user.user, conversation.account, account_user)
    end
  end

  def pundit_context(user, account, account_user = nil)
    {
      user: user,
      account: account,
      account_user: account_user || account.account_users.find_by(user_id: user.id)
    }
  end
end
