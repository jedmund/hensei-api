# frozen_string_literal: true

module BannerHistory
  # A read-only look at the cached Banner History: how many banners each year
  # has, the derived timeline, the items each banner features, and every name
  # that doesn't resolve to one of our items. Nothing is stored.
  class Report
    # What a banner shows: rate-ups (and zodiacs) on galas, featured items on
    # other draws, a collab's own items (and the ordinary ones in its pool).
    # 2014's banners list theirs as legacy_* fields.
    def self.featured_lists(entry)
      lists = entry.banner[:lists]
      if entry.collab?
        lists.slice('collab_wep', 'collab_sum', 'noncollab_wep')
      elsif entry.gala?
        lists.select { |field, _| field.start_with?('rateup_', 'legacy_') || field == 'zodiacs' }
      else
        lists.select { |field, _| field.start_with?('sparkable', 'rateup_', 'legacy_') }
      end
    end

    def initialize(pages: SourcePages.cached, archive: SourcePages.cached_archive, resolver: Resolver.new)
      @pages = pages
      @archive = ArchiveParser.parse(archive)
      @resolver = resolver
      @banners = pages.flat_map { |_, wikitext| Parser.parse(wikitext) } + @archive
      @timeline = Timeline.new(@banners)
    end

    attr_reader :timeline

    def run(io = $stdout)
      summary(io)
      featured = resolve_all
      problems(io)
      unresolved(io)
      collabs(io, featured)
      recent(io, featured)
    end

    private

    def summary(io)
      pages_summary(io)
      counts = @timeline.entries.group_by(&:type).transform_values(&:size).sort_by { |_, n| -n }
      io.puts "Types: #{counts.map { |type, n| "#{type} #{n}" }.join(', ')}"
      pools = @timeline.entries.group_by(&:pool).transform_values(&:size)
      io.puts "Pools: #{pools.map { |pool, n| "#{pool} #{n}" }.join(', ')}"
    end

    def pages_summary(io)
      io.puts "Pages cached: #{@pages.keys.join(', ')}"
      @pages.each { |year, wikitext| io.puts "  #{year}: #{Parser.parse(wikitext).size} banners" }
      by_year = @archive.group_by { |banner| banner[:start_date]&.year }.transform_values(&:size)
      io.puts "Archive (#{SourcePages::ARCHIVE}): #{@archive.size} banners — " \
              "#{by_year.sort_by { |year, _| year.to_i }.map { |year, n| "#{year}: #{n}" }.join(', ')}"
    end

    def resolve_all
      @timeline.entries.to_h do |entry|
        items = self.class.featured_lists(entry).flat_map do |field, names|
          model = Resolver.model_for(field, entry.type)
          names.map { |name| [field, name, @resolver.resolve(model, name, context: "#{entry.banner[:start_date]} #{entry.type}")] }
        end
        [entry, items]
      end
    end

    def problems(io)
      io.puts "\nTimeline problems: #{@timeline.problems.size}"
      @timeline.problems.first(40).each { |problem| io.puts "  #{problem}" }
    end

    def unresolved(io)
      misses = @resolver.unresolved
      io.puts "\nUnresolved names: #{misses.size}"
      misses.sort_by { |(model, name), _| [model, name] }.each do |(model, name), contexts|
        io.puts "  #{model}: #{name} (#{contexts.size}×, e.g. #{contexts.first})"
      end
    end

    def collabs(io, featured)
      io.puts "\nCollabs: #{@timeline.collabs.size}"
      @timeline.collabs.each do |entry|
        own = featured[entry].reject { |field, _, _| field == 'noncollab_wep' }
        io.puts "  #{entry.banner[:name] || '(unnamed)'}: #{span(entry)} — " \
                "#{own.map { |_, name, item| item ? name : "#{name}?" }.join('; ')}"
      end
    end

    def recent(io, featured)
      io.puts "\nLatest main-draw banners:"
      @timeline.main.last(12).each do |entry|
        names = featured[entry].map { |field, name, item| "#{name}#{'?' unless item}#{' (zodiac)' if field == 'zodiacs'}" }
        io.puts "  #{span(entry)} #{entry.type} → #{entry.pool}: #{names.first(6).join('; ')}#{'…' if names.size > 6}"
      end
    end

    def span(entry)
      ends = entry.ends_at ? entry.ends_at.strftime('%m-%d %H:%M') : 'now'
      "#{entry.starts_at.strftime('%Y-%m-%d %H:%M')} → #{ends}"
    end
  end
end
