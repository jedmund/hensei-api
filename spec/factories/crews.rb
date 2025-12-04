FactoryBot.define do
  factory :crew do
    name { Faker::Team.name }
    gamertag { Faker::Alphanumeric.alpha(number: 5).upcase }
    granblue_crew_id { Faker::Number.number(digits: 8).to_s }
    description { Faker::Lorem.paragraph }
  end
end
