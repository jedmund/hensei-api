# frozen_string_literal: true

module Api
  module V1
    # GET /home: everything the home page needs in one call. The payload is
    # cached briefly and shared by every viewer; the viewer's own stickers are
    # filled in after the cache read.
    class HomeController < Api::V1::ApiController
      include PartyQueryingConcern

      CACHE_TTL = 5.minutes
      # New characters also carry what the web's CharacterTags needs (element,
      # season, series, style swap), in CharacterBlueprint's shape.
      CHARACTER_TAG_FIELDS = %i[element season series series_names style_swap].freeze

      def show
        payload = Rails.cache.fetch(HomeFeed::CACHE_KEY, expires_in: CACHE_TTL) { build_payload }
        payload = with_my_stickers(payload.deep_dup) if current_user

        render json: payload
      end

      private

      def build_payload
        feed = HomeFeed.call
        party_ids = collect_party_ids(feed)
        parties = build_preview_base_query.where(id: party_ids).to_a
        options = { current_user: nil, party_labels: PartyStickerSummary.labels_for(party_ids), my_stickers: {} }
        rendered = PartyBlueprint.render_as_hash(parties, view: :list, **options).index_by { |hash| hash[:id] }
        by_id = parties.index_by(&:id)

        payload = {
          current: feed[:current].map { |section| render_section(section, rendered) },
          upcoming: feed[:upcoming].map do |section|
            render_section(section, rendered).merge(
              previous_event: section.previous_event && EventBlueprint.render_as_hash(section.previous_event)
            )
          end,
          rising: feed[:rising].filter_map { |id| rendered[id] },
          staff_picks: feed[:staff_picks].filter_map do |featured|
            party = by_id[featured.party_id]
            next unless party

            featured.association(:party).target = party
            FeaturedPartyBlueprint.render_as_hash(featured, **options)
          end,
          new_items: feed[:new_items].map do |entry|
            { item: render_item(entry), parties: entry.party_ids.filter_map { |id| rendered[id] } }
          end,
          new_battles: feed[:new_battles].map do |battle|
            {
              raid: RaidBlueprint.render_as_hash(battle.raid, view: :nested),
              recent: battle.recent_ids.filter_map { |id| rendered[id] },
              trending: battle.trending_ids.filter_map { |id| rendered[id] }
            }
          end
        }
        JSON.parse(payload.to_json)
      end

      def render_section(section, rendered)
        {
          event: EventBlueprint.render_as_hash(section.event),
          raids: section.raids.map do |raid_section|
            {
              raid: RaidBlueprint.render_as_hash(raid_section.raid, view: :list),
              parties: raid_section.party_ids.filter_map { |id| rendered[id] }
            }
          end
        }
      end

      def render_item(entry)
        item = entry.item
        rendered = {
          type: entry.type,
          id: item.id,
          granblue_id: item.granblue_id,
          name: { en: item.name_en, ja: item.name_jp },
          latest_date: item.latest_date,
          change: entry.change
        }
        if entry.type == 'character'
          rendered[:character] = CharacterBlueprint.render_as_hash(item).slice(*CHARACTER_TAG_FIELDS)
        end
        rendered
      end

      def collect_party_ids(feed)
        ids = (feed[:current] + feed[:upcoming]).flat_map { |section| section.raids.flat_map(&:party_ids) }
        ids.concat(feed[:rising])
        ids.concat(feed[:staff_picks].map(&:party_id))
        ids.concat(feed[:new_items].flat_map(&:party_ids))
        ids.concat(feed[:new_battles].flat_map { |battle| battle.recent_ids + battle.trending_ids })
        ids.uniq
      end

      # Every party hash in the payload, for filling in my_sticker.
      def party_hashes(payload)
        sections = payload['current'] + payload['upcoming']
        sections.flat_map { |section| section['raids'].flat_map { |raid| raid['parties'] } } +
          payload['rising'] +
          payload['staff_picks'].map { |featured| featured['party'] } +
          payload['new_items'].flat_map { |entry| entry['parties'] } +
          payload['new_battles'].flat_map { |battle| battle['recent'] + battle['trending'] }
      end

      def with_my_stickers(payload)
        hashes = party_hashes(payload)
        mine = PartyStickerSummary.my_stickers_for(current_user, hashes.map { |hash| hash['id'] })
        hashes.each { |hash| hash['my_sticker'] = mine[hash['id']] }
        payload
      end
    end
  end
end
