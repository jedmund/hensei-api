# frozen_string_literal: true

module Api
  module V1
    class WeaponKeyBlueprint < ApiBlueprint
      GAME_SERIES_IDS = GameDataImport::WEAPON_SERIES_SLUGS.invert.freeze

      field :name do |key|
        {
          en: key.name_en,
          ja: key.name_jp
        }
      end

      fields :granblue_id, :slug, :series, :slot, :group, :order

      # The game's series ids for the weapons this key fits, so the extension
      # can tell a key from a weapon's own skill that shares its skill id.
      field :game_series_ids do |key|
        key.weapon_series.filter_map { |series| GAME_SERIES_IDS[series.slug] }.sort
      end
    end
  end
end
