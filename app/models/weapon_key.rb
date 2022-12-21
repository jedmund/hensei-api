# frozen_string_literal: true

class WeaponKey < ApplicationRecord
  def blueprint
    WeaponKeyBlueprint
  end
end
