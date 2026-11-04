# frozen_string_literal: true

# A Guild War: an approved unite_and_fight Event with a number, timed like the
# real ones (Day 1 19:00 JST to the last day 23:59:59 JST).
FactoryBot.define do
  factory :gw_event, parent: :event do
    transient do
      start_date { 1.week.from_now.to_date }
      end_date { 2.weeks.from_now.to_date }
    end

    kind { :unite_and_fight }
    series { 'unite_and_fight' }
    element { :Fire }
    sequence(:event_number) { |n| n }
    name_en { "Unite and Fight ##{event_number}" }
    name_jp { "星の古戦場 第#{event_number}回" }
    starts_at { Event.gw_window(start_date, nil)[:starts_at] }
    ends_at { Event.gw_window(nil, end_date)[:ends_at] }

    trait :active do
      start_date { 2.days.ago.to_date }
      end_date { 5.days.from_now.to_date }
    end

    trait :finished do
      start_date { 3.weeks.ago.to_date }
      end_date { 2.weeks.ago.to_date }
    end

    trait :upcoming do
      start_date { 1.week.from_now.to_date }
      end_date { 2.weeks.from_now.to_date }
    end
  end
end
