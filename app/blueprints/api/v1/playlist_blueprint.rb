# frozen_string_literal: true

module Api
  module V1
    class PlaylistBlueprint < ApiBlueprint
      fields :title, :slug, :description, :video_url, :visibility,
             :created_at, :updated_at

      association :user,
                  blueprint: UserBlueprint,
                  view: :minimal

      # Only parties the viewer may see are listed or counted, so a party that
      # goes private drops out of other people's view of the playlist.
      # Render sites pass `visible_party_ids` (see .visible_party_ids_for) to
      # avoid a query per playlist.
      field :party_count do |playlist, options|
        visible_party_ids(playlist, options).size
      end

      field :party_ids do |playlist, options|
        visible_party_ids(playlist, options)
      end

      field :raid_slugs do |playlist, options|
        next options[:raid_slugs_map][playlist.id] || [] if options[:raid_slugs_map]

        party_ids = visible_party_ids(playlist, options)
        next [] if party_ids.empty?

        raid_ids = Party.where(id: party_ids)
                        .where.not(raid_id: nil)
                        .group(:raid_id)
                        .order(Arel.sql('MAX(last_updated) DESC'))
                        .limit(4)
                        .pluck(:raid_id)
        Raid.where(id: raid_ids).pluck(:slug)
      end

      view :with_parties do
        field :parties do |playlist, options|
          ordered = playlist.parties
                            .viewable_by(options[:current_user], admin_mode: options[:admin_mode])
                            .includes(:job, { raid: :group }, :solomonis_expedition,
                                      { characters: :character },
                                      { weapons: { weapon: :weapon_series } },
                                      { summons: :summon })
                            .order(last_updated: :desc)

          PartyBlueprint.render_as_hash(ordered, view: :list, current_user: options[:current_user],
                                                 admin_mode: options[:admin_mode])
        end
      end

      ##
      # The ids, across the given playlists, of parties the viewer may see.
      #
      # @param playlists [Enumerable<Playlist>] with playlist_parties loaded
      # @return [Set<String>]
      def self.visible_party_ids_for(playlists, current_user, admin_mode: false)
        ids = playlists.flat_map { |playlist| playlist.playlist_parties.map(&:party_id) }.uniq
        return Set.new if ids.empty?

        Party.viewable_by(current_user, admin_mode: admin_mode).where(id: ids).pluck(:id).to_set
      end

      def self.visible_party_ids(playlist, options)
        visible = options[:visible_party_ids] ||
                  visible_party_ids_for([playlist], options[:current_user], admin_mode: options[:admin_mode])
        playlist.playlist_parties.map(&:party_id).select { |id| visible.include?(id) }
      end
    end
  end
end
