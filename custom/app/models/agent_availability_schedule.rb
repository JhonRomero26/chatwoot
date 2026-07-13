# frozen_string_literal: true

class AgentAvailabilitySchedule < ApplicationRecord
  belongs_to :account_user

  before_validation :assign_timezone

  validates :day_of_week, presence: true, inclusion: { in: 0..6 }
  validates :timezone, presence: true, inclusion: { in: TZInfo::Timezone.all_identifiers }
  validates :start_minutes, :end_minutes, presence: true,
                                          numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 1439 }

  validate :range_is_ordered
  validate :range_does_not_overlap_siblings

  private

  def assign_timezone
    self.timezone = account_user&.account&.reporting_timezone.presence || 'UTC' if timezone.blank?
  end

  def range_is_ordered
    return if start_minutes.blank? || end_minutes.blank?
    return if start_minutes < end_minutes

    errors.add(:end_minutes, 'must be after the start time')
  end

  def range_does_not_overlap_siblings
    return if start_minutes.blank? || end_minutes.blank? || day_of_week.blank?

    overlapping = sibling_ranges.any? { |sibling| start_minutes < sibling.end_minutes && end_minutes > sibling.start_minutes }
    errors.add(:base, 'overlaps with another range on the same day') if overlapping
  end

  def sibling_ranges
    scope = self.class.where(account_user_id: account_user_id, day_of_week: day_of_week)
    scope = scope.where.not(id: id) if persisted?
    scope
  end
end
