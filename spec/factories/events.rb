FactoryBot.define do
  factory :event do
    sequence(:name) { |n| "Event #{n}" }
    sequence(:slug) { |n| "event-#{n}" }
    event_type { :unite_and_fight }
    start_time { 1.day.from_now }
    end_time { 3.days.from_now }
  end
end
