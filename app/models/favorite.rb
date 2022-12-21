# frozen_string_literal: true

class Favorite < ApplicationRecord
  belongs_to :user
  belongs_to :party

  def party
    Party.find(party_id)
  end
end
