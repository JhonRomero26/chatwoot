# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AgentAvailabilitySchedule do
  let(:account) { create(:account, reporting_timezone: 'America/New_York') }
  let(:account_user) { create(:account_user, account: account) }

  it 'defaults timezone from the account reporting timezone' do
    schedule = described_class.create!(account_user: account_user, day_of_week: 1, start_minutes: 540, end_minutes: 720)

    expect(schedule.timezone).to eq('America/New_York')
  end

  it 'falls back to UTC when the account reporting timezone is blank' do
    account.update!(reporting_timezone: nil)

    schedule = described_class.create!(account_user: account_user, day_of_week: 2, start_minutes: 780, end_minutes: 1020)

    expect(schedule.timezone).to eq('UTC')
  end

  it 'rejects a range where the end is not after the start' do
    schedule = described_class.new(account_user: account_user, day_of_week: 1, start_minutes: 720, end_minutes: 540)

    expect(schedule).to be_invalid
    expect(schedule.errors[:end_minutes]).to be_present
  end

  it 'rejects a range that overlaps an existing range on the same day' do
    described_class.create!(account_user: account_user, day_of_week: 1, start_minutes: 540, end_minutes: 720)
    overlapping = described_class.new(account_user: account_user, day_of_week: 1, start_minutes: 700, end_minutes: 800)

    expect(overlapping).to be_invalid
    expect(overlapping.errors[:base]).to be_present
  end

  it 'allows multiple non-overlapping ranges on the same day' do
    described_class.create!(account_user: account_user, day_of_week: 1, start_minutes: 540, end_minutes: 720)
    non_overlapping = described_class.new(account_user: account_user, day_of_week: 1, start_minutes: 780, end_minutes: 1020)

    expect(non_overlapping).to be_valid
  end

  it 'never treats ranges on different days as conflicting' do
    described_class.create!(account_user: account_user, day_of_week: 1, start_minutes: 540, end_minutes: 720)
    other_day = described_class.new(account_user: account_user, day_of_week: 2, start_minutes: 540, end_minutes: 720)

    expect(other_day).to be_valid
  end
end
