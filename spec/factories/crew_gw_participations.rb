FactoryBot.define do
  factory :crew_gw_participation do
    crew
    event factory: %i[gw_event]
    preliminary_ranking { nil }
    final_ranking { nil }
  end
end
