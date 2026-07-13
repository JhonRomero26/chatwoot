# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AgentAvailabilityFinder do
  let(:account) { create(:account) }
  let(:available_agent) { create(:user, account: account, role: :agent, name: 'Available Agent') }
  let(:afternoon_agent) { create(:user, account: account, role: :agent, name: 'Afternoon Agent') }
  let(:no_schedule_agent) { create(:user, account: account, role: :agent, name: 'No Schedule Agent') }

  before do
    create(:agent_availability_schedule,
           account_user: available_agent.account_users.find_by(account: account),
           day_of_week: 1,
           start_minutes: 540,
           end_minutes: 720)

    create(:agent_availability_schedule,
           account_user: afternoon_agent.account_users.find_by(account: account),
           day_of_week: 1,
           start_minutes: 780,
           end_minutes: 1020)
  end

  it 'returns only agents whose local time is inside a configured range' do
    account_users = described_class.new(account, Time.zone.parse('2026-07-13 10:00:00 UTC')).perform

    expect(account_users.map(&:user)).to contain_exactly(available_agent)
  end

  it 'treats missing schedules as unavailable' do
    account_users = described_class.new(account, Time.zone.parse('2026-07-13 14:00:00 UTC')).perform

    expect(account_users.map(&:user)).to contain_exactly(afternoon_agent)
    expect(account_users.map(&:user)).not_to include(no_schedule_agent)
  end

  it 'handles DST transitions using the row timezone' do
    dst_agent = create(:user, account: account, role: :agent, name: 'DST Agent')
    create(:agent_availability_schedule,
           account_user: dst_agent.account_users.find_by(account: account),
           day_of_week: 0,
           start_minutes: 90,
           end_minutes: 150,
           timezone: 'America/New_York')

    expect(described_class.new(account, Time.zone.parse('2026-03-08 06:45:00 UTC')).perform.map(&:user)).to include(dst_agent)
    expect(described_class.new(account, Time.zone.parse('2026-03-08 07:15:00 UTC')).perform.map(&:user)).not_to include(dst_agent)
  end

  it 'supports many ranges in a single day' do
    busy_agent = create(:user, account: account, role: :agent, name: 'Busy Agent')
    busy_account_user = busy_agent.account_users.find_by(account: account)

    create(:agent_availability_schedule, account_user: busy_account_user, day_of_week: 1, start_minutes: 540, end_minutes: 600)
    create(:agent_availability_schedule, account_user: busy_account_user, day_of_week: 1, start_minutes: 600, end_minutes: 660)
    create(:agent_availability_schedule, account_user: busy_account_user, day_of_week: 1, start_minutes: 1080, end_minutes: 1140)

    expect(described_class.new(account, Time.zone.parse('2026-07-13 09:30:00 UTC')).perform.map(&:user)).to include(busy_agent)
    expect(described_class.new(account, Time.zone.parse('2026-07-13 18:30:00 UTC')).perform.map(&:user)).to include(busy_agent)
    expect(described_class.new(account, Time.zone.parse('2026-07-13 13:00:00 UTC')).perform.map(&:user)).not_to include(busy_agent)
  end

  it 'treats end minutes as exclusive so adjacent ranges do not double count' do
    adjacent_agent = create(:user, account: account, role: :agent, name: 'Adjacent Agent')
    account_user = adjacent_agent.account_users.find_by(account: account)

    create(:agent_availability_schedule, account_user: account_user, day_of_week: 1, start_minutes: 540, end_minutes: 600)
    create(:agent_availability_schedule, account_user: account_user, day_of_week: 1, start_minutes: 600, end_minutes: 660)

    expect(described_class.new(account, Time.zone.parse('2026-07-13 10:00:00 UTC')).perform.map(&:user)).to include(adjacent_agent)
  end
end
