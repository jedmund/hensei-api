# frozen_string_literal: true

module Api
  module V1
    class WeaponStatModifierBlueprint < Blueprinter::Base
      identifier :id
      fields :slug, :name_en, :name_jp, :category, :stat, :polarity, :suffix, :base_min, :base_max
    end
  end
end
