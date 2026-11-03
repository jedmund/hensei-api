# frozen_string_literal: true

FactoryBot.define do
  factory :user_raid_element do
    user
    raid factory: %i[raid trackable]
    element { GranblueEnums::ELEMENTS[:Fire] }
  end
end
