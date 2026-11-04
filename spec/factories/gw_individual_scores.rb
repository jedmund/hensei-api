FactoryBot.define do
  factory :gw_individual_score do
    crew_gw_participation
    crew_membership
    round { :preliminaries }
    score { 100_000 }
    is_cumulative { false }
    association :recorded_by, factory: :user
  end
end
