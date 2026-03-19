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
        playlist.playlist_parties.map(&:party_id)
      end

      field :raid_slugs do |playlist, options|
        next options[:raid_slugs_map][playlist.id] || [] if options[:raid_slugs_map]

        party_ids = playlist.playlist_parties.map(&:party_id)
        next [] if party_ids.empty?

        raid_ids = Party.where(id: party_ids)
                        .where.not(raid_id: nil)
                        .group(:raid_id)
                        .order(Arel.sql('MAX(updated_at) DESC'))
                        .limit(4)
                        .pluck(:raid_id)
        Raid.where(id: raid_ids).pluck(:slug)
      end

      view :with_parties do
        field :parties do |playlist, _options|
          ordered = playlist.parties.includes(
            :job, { raid: :group },
            { characters: :character },
            { weapons: :weapon },
            { summons: :summon }
          ).order(updated_at: :desc)

          PartyBlueprint.render_as_hash(ordered, view: :list)
        end
      end
    end
  end
end
