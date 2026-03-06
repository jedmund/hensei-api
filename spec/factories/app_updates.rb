# frozen_string_literal: true

FactoryBot.define do
  factory :app_update do
    update_type { 'characters' }
    version { nil }

    trait :with_version do
      version { '2.0' }
    end
  end
end
