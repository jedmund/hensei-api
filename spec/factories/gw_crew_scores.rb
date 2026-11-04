FactoryBot.define do
  factory :gw_crew_score do
    crew_gw_participation
    round { :preliminaries }
    crew_score { 1_000_000 }
    opponent_score { nil }
    opponent_name { nil }
    opponent_granblue_id { nil }
    victory { nil }

    trait :with_opponent do
      opponent_score { 900_000 }
      opponent_name { 'Opponent Crew' }
      sequence(:opponent_granblue_id) { |n| (30_000_000 + n).to_s }
    end

    trait :victory do
      with_opponent
      crew_score { 10_000_000 }
      opponent_score { 5_000_000 }
    end

    trait :defeat do
      with_opponent
      crew_score { 5_000_000 }
      opponent_score { 10_000_000 }
    end
  end
end
