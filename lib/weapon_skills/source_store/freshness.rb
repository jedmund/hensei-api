# frozen_string_literal: true

module WeaponSkills
  module SourceStore
    # Which stored sources the wiki has edited since they were fetched, asked 50 titles per
    # request (about 45 requests for the whole store) instead of refetching every page.
    #
    # A weapon is stale when its page or a page its parse follows (a transclusion, such as
    # Template:Weapon/Common/Destroyer) changed; its expansion is refetched with it. Edits
    # to templates deeper than that aren't seen; refetch with stale_days for those.
    class Freshness
      KINDS = %w[wiki_raw transclusion family_template].freeze

      Result = Struct.new(:weapon_ids, :shared, :missing, :checked, keyword_init: true) do
        def stale? = weapon_ids.any? || shared.any?
      end

      def initialize(fetcher:)
        @fetcher = fetcher
      end

      # → Result: weapon_ids to refetch, shared [kind, key] pages to refetch, titles the wiki
      # no longer has, and how many titles were checked.
      def check(scope = WeaponSource.all)
        rows = scope.where(kind: KINDS).pluck(:weapon_id, :kind, :key, :fetched_at)
        titles = rows.map { |r| r[2] }.uniq.sort
        edited = titles.each_slice(50).with_object({}) { |slice, out| out.merge!(@fetcher.last_edited(slice)) }

        missing = titles.select { |t| edited[t].nil? }
        stale = rows.select { |_, _, key, fetched_at| edited[key] && edited[key] > fetched_at }
        Result.new(weapon_ids: stale.filter_map(&:first).uniq,
                   shared: stale.select { |weapon_id, *| weapon_id.nil? }.map { |_, kind, key, _| [kind, key] }.uniq,
                   missing: missing, checked: titles.size)
      end

      # Refetches what check found stale. → the fetcher's stats
      def refetch(result, log: nil)
        Weapon.where(id: result.weapon_ids).order(:granblue_id).each do |weapon|
          @fetcher.fetch_weapon(weapon)
          log&.call("  refetched #{weapon.granblue_id} #{weapon.name_en}")
        rescue StandardError => e
          log&.call("  ERROR #{weapon.granblue_id} #{weapon.name_en}: #{e.message}")
        end
        result.shared.each do |kind, key|
          if kind == "family_template"
            @fetcher.fetch_family_template(key.delete_prefix(Granblue::Extractors::FamilyTemplateImporter.template_title("")))
          else
            @fetcher.fetch_series_page(key)
          end
          log&.call("  refetched #{kind} #{key}")
        end
        @fetcher.stats
      end
    end
  end
end
