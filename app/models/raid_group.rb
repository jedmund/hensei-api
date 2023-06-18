# frozen_string_literal: true

class RaidGroup < ApplicationRecord
  has_many :raids, class_name: 'Raid', foreign_key: :group_id

  def blueprint
    RaidGroupBlueprint
  end
end
