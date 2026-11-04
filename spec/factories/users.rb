FactoryBot.define do
  # Defaults are fixed (they match the column defaults) so specs don't depend
  # on the seed. Use a trait or an explicit attribute for anything else.
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 'password' }
    password_confirmation { 'password' }
    sequence(:username) { |n| "user#{n}" }
    sequence(:granblue_id) { |n| 20_000_000 + n }
    wiki_profile { nil }
    youtube { nil }
    picture { 'gran' }
    language { 'en' }
    private { false }
    element { 'water' }
    gender { 0 }
    theme { 'system' }
    role { 1 }

    trait :japanese do
      language { 'ja' }
    end
  end
end
