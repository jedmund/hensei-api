FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    password { "password" }
    password_confirmation { "password" }
    username { Faker::Internet.username(specifier: 5..8) }
    granblue_id { Faker::Number.number(digits: 4) }
    picture { "gran" }
    language { ["en", "ja"].sample }
    private { Faker::Boolean.boolean }
    element { ["water", "fire", "wind", "earth", "light", "dark"].sample }
    gender { Faker::Number.between(from: 0, to: 1) }
    theme { ["system", "dark", "light"].sample }
    role { Faker::Number.between(from: 1, to: 3) }
  end
end
