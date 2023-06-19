# frozen_string_literal: true

class Raid < ApplicationRecord
  belongs_to :group, class_name: 'RaidGroup', foreign_key: :group_id

  def blueprint
    RaidBlueprint
  end
end
