FactoryBot.define do
  factory :crew_gw_participation do
    crew
    association :event, factory: :gw_event
    preliminary_ranking { nil }
    final_ranking { nil }
  end
end
