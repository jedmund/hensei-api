# frozen_string_literal: true

module Granblue
  # rake granblue:fetch_wiki_data: fetches gbf.wiki pages into wiki_raw for Characters,
  # Weapons or Summons, one request per row and Granblue::WikiThrottle between requests.
  #
  #   ids:      granblue_ids (both style rows of a character)
  #   rarities: [1, 2, 3] subset
  #   force:    refetch rows that already have wiki_raw (otherwise they're skipped)
  #
  # Returns a Granblue::SourceFetchSummary: a fetched row is "unchanged" when the page
  # is the same text as stored, otherwise "changed".
  class WikiDataFetch
    def initialize(klass, delay:, ids: nil, rarities: nil, force: false, io: $stdout)
      @klass = klass
      @ids = ids
      @rarities = rarities
      @force = force
      @delay = delay
      @io = io
      @summary = SourceFetchSummary.new('fetch_wiki_data')
    end

    def scope
      query = @klass.all
      query = query.where(granblue_id: @ids) if @ids
      query = query.where(rarity: @rarities) if @rarities
      query
    end

    def call
      report_unknown_ids
      total = scope.count
      @io.puts "Fetching wiki_raw for up to #{total} #{@klass.name.pluralize}" \
               "#{' (force: refetching stored pages)' if @force} at #{@delay}s per request..."

      scope.find_each(batch_size: 100).with_index(1) do |object, index|
        fetch_one(object, index, total)
      end
      @summary.print(@io)
      @summary
    end

    private

    def fetch_one(object, index, total)
      return @summary.skipped!('has wiki_raw') if object.wiki_raw.present? && !@force
      return skip_no_page(object) if object.wiki_en.blank?

      requested = true
      before = object.wiki_raw
      text = WikiFetcher.new(delay: @delay).fetch_and_store(object)
      @summary.fetched!(object.granblue_id, before: before, after: text)
      @io.puts "  [#{index}/#{total}] #{label(object)}: #{before == text ? 'unchanged' : 'changed'}"
    rescue StandardError => e
      @summary.error!(object.granblue_id, "#{e.class}: #{e.message}", label: label(object))
      @io.puts "  [#{index}/#{total}] #{label(object)}: ERROR #{e.message}"
    ensure
      WikiThrottle.wait(@delay) if requested
    end

    def skip_no_page(object)
      @summary.skipped!('no wiki_en')
      @io.puts "  #{label(object)}: skipped (no wiki_en set)"
    end

    def report_unknown_ids
      return unless @ids

      unknown = @ids - @klass.where(granblue_id: @ids).distinct.pluck(:granblue_id)
      unknown.each { @summary.skipped!('not in database') }
      @io.puts "Not in the database: #{unknown.join(', ')}" if unknown.any?
    end

    def label(object)
      style = " (style #{object.style_name_en.presence || 2})" if object.try(:style_swap)
      "#{object.granblue_id} #{object.name_en}#{style}"
    end
  end
end
