# frozen_string_literal: true

module Custom::AccountUser
  def self.prepended(base)
    base.has_many :agent_availability_schedules, dependent: :destroy
    base.belongs_to :agent_role, optional: true
    base.validate :availability_schedule_timezone_is_valid
  end

  def permissions
    return super if administrator? || custom_role_id.present?

    super + agent_role_permissions
  end

  def privileged?
    administrator? || conversation_manage?
  end

  def conversation_manage?
    administrator? || permissions.include?('conversation_manage')
  end

  def report_manage?
    administrator? || permissions.include?('report_manage')
  end

  private

  def filtered_unread_count_visibility_changed?
    super || previous_changes.key?('agent_role_id')
  end

  def agent_role_permissions
    agent_role&.permissions || []
  end

  def availability_schedule_timezone_is_valid
    return if availability_schedule_timezone.blank?
    return if TZInfo::Timezone.all_identifiers.include?(availability_schedule_timezone)

    errors.add(:availability_schedule_timezone, 'is not a valid timezone')
  end
end
