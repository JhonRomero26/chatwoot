# frozen_string_literal: true

class AgentAvailabilityFinder
  def initialize(account, now = Time.current)
    @account = account
    @now = now
  end

  def perform
    available_account_users.sort_by { |account_user| account_user.user.available_name.downcase }
  end

  private

  attr_reader :account, :now

  def available_account_users
    account_users_by_id.values_at(*available_account_user_ids).compact
  end

  def available_account_user_ids
    schedules.each_with_object([]) do |schedule, ids|
      ids << schedule.account_user_id if available_now?(schedule)
    end
  end

  def schedules
    @schedules ||= AgentAvailabilitySchedule.where(account_user_id: account_users_by_id.keys)
  end

  def account_users_by_id
    @account_users_by_id ||= account.account_users.agent.includes(:user).index_by(&:id)
  end

  def available_now?(schedule)
    local_now = now.in_time_zone(schedule.timezone)
    return false unless schedule.day_of_week == local_now.wday

    local_minutes = (local_now.hour * 60) + local_now.min
    local_minutes.between?(schedule.start_minutes, schedule.end_minutes)
  end
end
