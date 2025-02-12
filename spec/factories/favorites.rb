# frozen_string_literal: true
#
# Factory for the Favorite model. This factory sets up the associations to User and Party,
# which are required as per the model definition.
#
FactoryBot.define do
  factory :favorite do
    association :user
    association :party
  end
end
