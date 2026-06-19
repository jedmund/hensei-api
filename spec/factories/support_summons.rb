FactoryBot.define do
  factory :support_summon do
    user
    collection_summon { association :collection_summon, user: user }
    section { :fire }
    position { 0 }
  end
end
