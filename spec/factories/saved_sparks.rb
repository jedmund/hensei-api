# frozen_string_literal: true

FactoryBot.define do
  factory :saved_spark do
    user
    spark_date { Date.current }
    draws { 300 }
    characters { %w[1040000000 1040000100] }
    moons { %w[1040000200] }
    summons { %w[2040000000] }
  end
end
