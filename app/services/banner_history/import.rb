# frozen_string_literal: true

module BannerHistory
  # Rebuilds historical_banners and their items from the cached Banner History
  # pages. Everything is replaced in one transaction, so it can run again
  # whenever the cache changes. A character is recorded as the weapon that
  # recruits them, the way the gacha catalogue lists characters; a name that
  # doesn't resolve is left out and reported.
  class Import
    Result = Struct.new(:banners, :items, :unresolved, keyword_init: true)

    def initialize(pages: SourcePages.cached, archive: SourcePages.cached_archive, resolver: Resolver.new)
      @pages = pages
      @archive = archive
      @resolver = resolver
    end

    def call
      pages = @pages.flat_map { |year, wikitext| Parser.parse(wikitext, source_key: SourcePages.title(year)) }
      timeline = Timeline.new(pages + ArchiveParser.parse(@archive))
      now = Time.current
      banners = timeline.entries.map { |entry| [entry, banner_row(entry, now)] }
      items = HistoricalBanner.transaction { replace(banners) }
      Result.new(banners: banners.size, items: items, unresolved: @resolver.unresolved)
    end

    private

    # Swaps every banner and item for the new ones. → the number of items
    def replace(banners)
      HistoricalBanner.delete_all
      ids = HistoricalBanner.insert_all!(banners.map(&:last), returning: %i[id key]).to_h { |row| [row['key'], row['id']] }
      rows = banners.flat_map { |entry, row| item_rows(entry, ids.fetch(row[:key])) }
      rows = rows.uniq { |row| row.values_at(:historical_banner_id, :granblue_id, :role) }
      HistoricalBannerItem.insert_all!(rows) if rows.any?
      rows.size
    end

    def banner_row(entry, now)
      banner = entry.banner
      {
        key: [entry.starts_at.iso8601, entry.type, banner[:name]].compact.join(' '),
        kind: entry.type, pool: entry.pool, name: banner[:name],
        starts_at: entry.starts_at, ends_at: entry.ends_at,
        ssr_rate: ssr_rate(entry), source_key: banner[:source_key] || SourcePages::ARCHIVE,
        created_at: now, updated_at: now
      }
    end

    def ssr_rate(entry)
      return nil if entry.collab?

      entry.gala? ? 6 : 3
    end

    def item_rows(entry, banner_id)
      Featured.lists(entry).flat_map do |field, names|
        model = Resolver.model_for(field, entry.type)
        role = Featured.role(entry, field)
        names.flat_map do |name|
          item = @resolver.resolve(model, name, context: "#{entry.banner[:start_date]} #{entry.type}")
          next [] unless item

          catalogue_ids(model, item.granblue_id).map do |granblue_id, item_type|
            { historical_banner_id: banner_id, granblue_id: granblue_id, item_type: item_type, role: role, wiki_name: name }
          end
        end
      end
    end

    # A character's recruiting weapons; a weapon or summon as itself
    def catalogue_ids(model, granblue_id)
      return [[granblue_id, model.name]] unless model == Character

      @recruits ||= Weapon.where.not(recruits: nil).pluck(:recruits, :granblue_id).group_by(&:first)
      Array(@recruits[granblue_id]).map { |(_, weapon_id)| [weapon_id, 'Weapon'] }
    end
  end
end
