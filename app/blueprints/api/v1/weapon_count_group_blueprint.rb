# frozen_string_literal: true

module Api
  module V1
    class WeaponCountGroupBlueprint < ApiBlueprint
      fields :slug, :name_en, :name_jp, :notes, :created_at, :updated_at

      field :weapon_count do |group|
        group.weapons.size
      end

      field :weapon_granblue_ids do |group|
        group.weapons.sort_by(&:granblue_id).map(&:granblue_id)
      end
    end
  end
end
