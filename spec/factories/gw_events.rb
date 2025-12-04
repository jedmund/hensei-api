FactoryBot.define do
  factory :gw_event do
    element { %i[Fire Water Earth Wind Light Dark].sample }
    start_date { 1.week.from_now.to_date }
    end_date { 2.weeks.from_now.to_date }
    sequence(:event_number) { |n| n }

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
