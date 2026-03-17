# frozen_string_literal: true

module Api
  module V1
    class PlaylistBlueprint < ApiBlueprint
      fields :title, :slug, :description, :video_url, :visibility,
             :created_at, :updated_at

      association :user,
                  blueprint: UserBlueprint,
                  view: :minimal

      field :party_count do |playlist|
        playlist.playlist_parties.size
      end

      field :party_ids do |playlist|
        playlist.playlist_parties.pluck(:party_id)
      end

      view :with_parties do
        field :parties do |playlist, options|
          ordered = playlist.parties.includes(
            :user, :job, { raid: :group },
            { characters: { character: :character_series_records } },
            { weapons: { weapon: [:awakenings, :weapon_series, :weapon_series_variant] } },
            { summons: :summon }
          ).order(updated_at: :desc)

          PartyBlueprint.render_as_hash(
            ordered,
            view: :preview,
            current_user: options[:current_user],
            favorite_party_ids: options[:favorite_party_ids] || Set.new
          )
        end
      end
    end
  end
end
