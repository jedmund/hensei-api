# frozen_string_literal: true

require 'httparty'

module Granblue
  module Schedule
    # The EN half of the event schedule: gbf.wiki's Cargo table `event_history`
    # (the table Module:Events reads to build the wiki's main-page event list).
    #
    # fetch makes one cargoquery request and returns the raw body untouched; the
    # caller saves it, and parse only ever reads a saved body. Nothing here retries
    # or works around a block: a Cloudflare challenge or an error raises WikiError.
    #
    #   source = WikiSource.new
    #   raw = source.fetch                # one request; store it
    #   records = source.parse(raw)       # normalized hashes (see Normalization)
    #   source.warnings                   # rows or values it couldn't fully read
    #
    # Real columns (from action=cargofields, 2026-10-17; Module:Events uses
    # aliases for them): utc_start/utc_end are Unix epochs; jst_start/jst_end are
    # utc + 9h and NOT real epochs, so they're never used as times. `type` is
    # always empty; `grp` is set only for recurring events. `element` and
    # `unf_element` are lowercase and are the BOSS element.
    class WikiSource
      SOURCE = 'gbf_wiki'
      TABLE = 'event_history'

      FIELDS = %w[
        unique_key name type grp enname jpname wiki_page time_known time_start time_end
        utc_start utc_end jst_start jst_end enimage jpimage unf_element element
      ].freeze

      # `grp` → kind. Only recurring events have a grp (seen: these three).
      GROUP_KINDS = {
        'Unite and Fight' => 'unite_and_fight',
        'Dread Barrage' => 'dread_barrage',
        'Rise of the Beasts' => 'farming'
      }.freeze

      # Name patterns for rows without a grp, first match wins. Anything
      # unmatched stays nil for an editor to pick (story events have no marker
      # in the name).
      NAME_KINDS = [
        [/alchemist|alchemy/i, 'alchemy'],
        # A returning collab is still a collab.
        [/gin ?tama|my hero academia|bleach|collab/i, 'collab'],
        [/rerun/i, 'rerun'],
        [/missions?\b|bonanza|campaign|trick or treat/i, 'other']
      ].freeze

      CHALLENGE_MARKERS = ['cf-chl', 'challenge-platform', 'Just a moment...'].freeze

      attr_reader :warnings

      def initialize
        @warnings = []
      end

      # One cargoquery request through the wiki parser's endpoint and user agent,
      # for events starting in [from, to]. Returns the response body as a String.
      # Raises WikiError on a challenge, a non-JSON body or a non-200 status.
      def fetch(from: 3.months.ago, to: 3.months.from_now, limit: 100)
        user_agent = Rails.application.credentials.wiki_user_agent
        if user_agent.blank?
          raise WikiError.new(code: nil, message: 'wiki_user_agent credential is missing', page: TABLE)
        end

        response = HTTParty.get(Granblue::Parsers::Wiki.base_uri,
                                query: query_params(from: from, to: to, limit: limit),
                                headers: { 'User-Agent' => user_agent },
                                format: :plain)
        body = response.body.to_s
        check_response!(response.code, body)
        body
      end

      def query_params(from:, to:, limit: 100)
        {
          action: 'cargoquery',
          format: 'json',
          tables: TABLE,
          fields: FIELDS.join(','),
          where: "utc_start >= #{from.to_i} AND utc_start <= #{to.to_i}",
          order_by: 'utc_start',
          limit: limit
        }
      end

      # raw_json: a saved cargoquery body (String) or its parsed Hash.
      # from/to (optional): keep only rows whose window overlaps [from, to].
      def parse(raw_json, from: nil, to: nil)
        @warnings = []
        data = raw_json.is_a?(String) ? JSON.parse(raw_json) : raw_json
        if data['error']
          @warnings << "cargoquery error: #{data.dig('error', 'code')} #{data.dig('error', 'info')}"
          return []
        end

        rows = Array(data['cargoquery']).map { |entry| normalize_keys(entry['title'] || entry) }
        records = rows.each_with_index.filter_map { |row, index| build_record(row, index) }
        records.select { |r| in_window?(r, from, to) }
      end

      private

      def check_response!(code, body)
        if CHALLENGE_MARKERS.any? { |marker| body.include?(marker) }
          raise WikiError.new(code: code, message: 'Blocked by a Cloudflare challenge', page: TABLE)
        end
        raise WikiError.new(code: code, message: 'Unexpected response', page: TABLE) unless code == 200

        JSON.parse(body)
      rescue JSON::ParserError
        raise WikiError.new(code: code, message: 'Response is not JSON', page: TABLE)
      end

      # Cargo's API returns field names with underscores as spaces ("utc start").
      def normalize_keys(row)
        row.to_h.transform_keys { |key| key.to_s.strip.tr(' ', '_') }
      end

      def build_record(row, index)
        name = (row['enname'].presence || row['name']).to_s.strip
        label = name.presence || "row #{index}"
        if name.empty?
          @warnings << "#{label}: no name, skipped"
          return nil
        end

        starts_at = epoch(row['utc_start'])
        ends_at = epoch(row['utc_end'])
        unless starts_at && ends_at
          @warnings << "#{label}: no readable utc_start/utc_end, skipped"
          return nil
        end
        @warnings << "#{label}: ends before it starts" if ends_at < starts_at
        @warnings << "#{label}: time_known is #{row['time_known'].inspect}" if time_unknown?(row['time_known'])

        Normalization.record(
          name_en: name,
          name_jp: row['jpname'].to_s.strip.presence,
          starts_at: starts_at,
          ends_at: ends_at,
          kind_guess: kind_for(row, label),
          element: element_for(row, label),
          image_en: first_image(row['enimage']),
          image_jp: first_image(row['jpimage']),
          source: SOURCE,
          source_id: row['unique_key'].presence || name,
          raw: row
        )
      end

      def epoch(value)
        text = value.to_s.strip
        return nil unless text.match?(/\A\d+\z/)

        Time.at(text.to_i).in_time_zone(Normalization.jst)
      end

      def time_unknown?(value)
        %w[0 no false].include?(value.to_s.strip.downcase)
      end

      # enimage/jpimage can hold several files separated by ";"; the first is the banner.
      def first_image(value)
        value.to_s.split(';').map(&:strip).find(&:present?)
      end

      def kind_for(row, label)
        group = row['grp'].to_s.strip
        return GROUP_KINDS[group] if GROUP_KINDS.key?(group)

        @warnings << "#{label}: unmapped grp #{group.inspect}" if group.present?
        NAME_KINDS.find { |pattern, _| label.match?(pattern) }&.last
      end

      # `element` is the boss element; unf_element repeats it on recurring events.
      def element_for(row, label)
        value = row['element'].to_s.strip
        unf = row['unf_element'].to_s.strip
        if value.present? && unf.present? && !value.casecmp?(unf)
          @warnings << "#{label}: element #{value.inspect} and unf_element #{unf.inspect} differ"
        end
        return nil if value.empty?

        name = Normalization.element_name(value)
        @warnings << "#{label}: unrecognised element #{value.inspect}" unless name
        name
      end

      def in_window?(record, from, to)
        return false if from && record[:ends_at] < from
        return false if to && record[:starts_at] > to

        true
      end
    end
  end
end
