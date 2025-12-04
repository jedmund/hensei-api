FactoryBot.define do
  factory :gw_individual_score do
    crew_gw_participation
    crew_membership
    round { :preliminaries }
    score { Faker::Number.between(from: 10_000, to: 1_000_000) }
    is_cumulative { false }
    association :recorded_by, factory: :user
  end
end
