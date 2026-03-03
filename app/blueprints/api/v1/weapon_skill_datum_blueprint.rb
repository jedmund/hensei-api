# frozen_string_literal: true

module Api
  module V1
    class WeaponSkillDatumBlueprint < Blueprinter::Base
      identifier :id

      fields :modifier, :boost_type, :series, :size, :formula_type, :aura_boostable

      field :sl1 do |datum|
        datum.sl1&.to_f
      end

      field :sl10 do |datum|
        datum.sl10&.to_f
      end

      field :sl15 do |datum|
        datum.sl15&.to_f
      end

      field :sl20 do |datum|
        datum.sl20&.to_f
      end

      field :sl25 do |datum|
        datum.sl25&.to_f
      end

      field :coefficient do |datum|
        datum.coefficient&.to_f
      end
    end
  end
end
