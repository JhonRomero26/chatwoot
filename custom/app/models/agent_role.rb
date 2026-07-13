# frozen_string_literal: true

class AgentRole < ApplicationRecord
  PERMISSIONS = %w[conversation_manage report_manage].freeze

  belongs_to :account
  has_many :account_users, dependent: :nullify

  before_destroy :capture_filtered_unread_count_user_ids, prepend: true
  after_update_commit :invalidate_filtered_unread_count_visibility_update, if: :saved_change_to_permissions?
  after_destroy_commit :invalidate_filtered_unread_count_visibility_destroy

  validates :name, presence: true, uniqueness: { scope: :account_id }
  validate :permissions_are_supported

  private

  def capture_filtered_unread_count_user_ids
    @filtered_unread_count_user_ids = account_users.pluck(:user_id)
  end

  def invalidate_filtered_unread_count_visibility_update
    invalidate_filtered_unread_count_visibility(account_users.pluck(:user_id))
  end

  def invalidate_filtered_unread_count_visibility_destroy
    invalidate_filtered_unread_count_visibility(@filtered_unread_count_user_ids)
  end

  def invalidate_filtered_unread_count_visibility(user_ids)
    return if user_ids.blank?

    invalidator = ::Conversations::UnreadCounts::FilteredCountInvalidator.new(account)
    visibility_changed = invalidator.users_visibility_changed!(user_ids: user_ids)

    return unless visibility_changed

    Rails.configuration.dispatcher.dispatch(ACCOUNT_CACHE_INVALIDATED, Time.zone.now, account: account, cache_keys: account.cache_keys)
  end

  def permissions_are_supported
    invalid_permissions = permissions - PERMISSIONS
    return if invalid_permissions.empty?

    errors.add(:permissions, "contains unsupported values: #{invalid_permissions.join(', ')}")
  end
end
