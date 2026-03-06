# frozen_string_literal: true

FactoryBot.define do
  factory :data_version do
    sequence(:filename) { |n| "data_import_#{n}.csv" }
    imported_at { Time.current }
  end
end
