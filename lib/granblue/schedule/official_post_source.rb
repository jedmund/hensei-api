# frozen_string_literal: true

module Granblue
  module Schedule
    # The JA half of the event schedule: the official site's monthly post
    # これからの『グランブルーファンタジー』YYYY年MM月号, served as JSON by the
    # site's CMS (`/rcms-api/1/news`). The post body (`content`) is prose HTML:
    # one <h1> per announcement, event names in 「…」, and an <h4>開催期間</h4>
    # followed by a <p> holding the period.
    #
    # Only sections with a 開催期間 block become records. Anything that looks
    # like an event but can't be read goes into warnings instead of being
    # dropped, so an editor sees it.
    #
    #   source = OfficialPostSource.new
    #   post = source.find_monthly_post(news_json, year: 2026, month: 10)
    #   records = source.parse_post(post)    # or parse(html, year:, month:)
    #   source.warnings
    class OfficialPostSource
      SOURCE = 'official_site'
      NEWS_URL = 'https://granbluefantasy.com/rcms-api/1/news'

      SUBJECT_PATTERN = /これからの『グランブルーファンタジー』\s*(\d{4})年\s*(\d{1,2})月号/
      PERIOD_HEADINGS = /開催期間|開催日時|実施期間/

      # The range separators seen or likely: ～ (U+FF5E, becomes ~ under NFKC),
      # 〜 (U+301C, survives NFKC), and dashes.
      SEPARATOR = /\s*[~〜‐-―−－-]\s*/
      ENDPOINT = %r{
        \A
        (?:(?<year>\d{4})\s*[/年]\s*)?
        (?<month>\d{1,2})\s*[/月]\s*(?<day>\d{1,2})\s*日?
        \s*(?:\([^)]*\))?                 # weekday, e.g. (水)
        \s*(?:(?<hour>\d{1,2})\s*:\s*(?<minute>\d{2}))?
        \s*(?<rest>.*)
        \z
      }x
      # A short label before the range, e.g. 後半：
      LABEL = /\A[^\d:]{1,10}:\s*/
      # What may trail an endpoint without making the line ambiguous.
      ALLOWED_REST = /\A(?:まで.*|頃|ごろ|予定|\s*)\z/

      # First match wins, so a 復刻コラボ is a rerun.
      KIND_PATTERNS = [
        [/古戦場|Unite and Fight/i, 'unite_and_fight'],
        [/ドレッドバラージュ/, 'dread_barrage'],
        [/四象降臨/, 'farming'],
        [/錬金/, 'alchemy'],
        # A returning collab (復刻コラボ) is still a collab.
        [/コラボ/, 'collab'],
        [/復刻/, 'rerun'],
        [/キャンペーン|ミッション/, 'other'],
        [/\Aイベント「/, 'story_event']
      ].freeze

      attr_reader :warnings

      def initialize
        @warnings = []
      end

      # news_json: the CMS response (String or Hash). Every monthly post in it,
      # as { post:, year:, month: }. The subject's month wins over `ymd`.
      def monthly_posts(news_json)
        data = news_json.is_a?(String) ? JSON.parse(news_json) : news_json
        Array(data['list']).filter_map do |post|
          match = post['subject'].to_s.unicode_normalize(:nfkc).match(SUBJECT_PATTERN)
          { post: post, year: match[1].to_i, month: match[2].to_i } if match
        end
      end

      def find_monthly_post(news_json, year:, month:)
        monthly_posts(news_json).find { |entry| entry[:year] == year && entry[:month] == month }&.fetch(:post)
      end

      # Parses a post found by find_monthly_post, reading year and month from its subject.
      def parse_post(post)
        match = post['subject'].to_s.unicode_normalize(:nfkc).match(SUBJECT_PATTERN)
        raise ArgumentError, "not a monthly post: #{post['subject'].inspect}" unless match

        parse(post['content'].to_s, year: match[1].to_i, month: match[2].to_i, post_id: post['topics_id'])
      end

      # content_html: the post's `content`. year/month: the issue (2026年10月号),
      # used for dates written without a year. → normalized record hashes.
      def parse(content_html, year:, month:, post_id: nil)
        @warnings = []
        list = sections(content_html)
        if list.empty? && content_html.to_s.strip.present?
          @warnings << 'no <h1> sections found; the post structure may have changed'
        end
        list.each_with_index.filter_map do |section, index|
          build_record(section, index, year: year, month: month, post_id: post_id)
        end
      end

      # One 開催期間 line → [starts_at, ends_at] in JST, or nil if it isn't a
      # complete, unambiguous range. Exposed for specs and editor tooling.
      def parse_period(line, year:, month:)
        text = line.to_s.unicode_normalize(:nfkc).strip
        text = text.sub(LABEL, '')
        parts = text.split(SEPARATOR, -1)
        return nil unless parts.size == 2

        start = parse_endpoint(parts[0])
        finish = parse_endpoint(parts[1])
        return nil unless start && finish

        start_year = start[:year] || infer_year(start[:month], year, month)
        end_year = finish[:year] || (finish[:month] < start[:month] ? start_year + 1 : start_year)
        starts_at = build_time(start_year, start)
        ends_at = build_time(end_year, finish)
        return nil unless starts_at && ends_at && ends_at > starts_at

        [starts_at, ends_at]
      end

      private

      Section = Struct.new(:heading, :nodes)

      # Splits the post into one Section per <h1>; the intro before the first is dropped.
      def sections(content_html)
        fragment = Nokogiri::HTML::DocumentFragment.parse(content_html.to_s)
        fragment.children.each_with_object([]) do |node, list|
          if node.element? && node.name == 'h1'
            list << Section.new(text_of(node), [])
          elsif list.any?
            list.last.nodes << node
          end
        end
      end

      def build_record(section, index, year:, month:, post_id:)
        name = event_name(section.heading)
        lines = period_lines(section)
        if lines.nil?
          @warnings << "#{section.heading}: announces an event but has no 開催期間" if announces_event?(section.heading)
          return nil
        end

        if lines.empty?
          @warnings << "#{name}: 開催期間 block is empty"
          return nil
        end

        ranges = lines.map { |line| [line, parse_period(line, year: year, month: month)] }
        parsed = ranges.select { |_, range| range }
        ranges.reject { |_, range| range }.map(&:first).each do |line|
          @warnings << "#{name}: can't read 開催期間 line #{line.inspect}"
        end
        return nil if parsed.empty?

        parsed.drop(1).map(&:first).each { |line| @warnings << "#{name}: extra 開催期間 line ignored #{line.inspect}" }
        line, (starts_at, ends_at) = parsed.first
        body = section.nodes.map { |node| text_of(node) }.join("\n")
        boss, advantage = elements(body, name)

        Normalization.record(
          name_en: nil,
          name_jp: name,
          starts_at: starts_at,
          ends_at: ends_at,
          kind_guess: kind_for(section.heading),
          element: boss,
          image_en: nil,
          image_jp: first_image(section),
          source: SOURCE,
          source_id: [post_id, index].compact.join(':'),
          raw: { heading: section.heading, period: line, enemy_element: boss,
                 advantage_element: advantage, post_id: post_id, section_index: index }
        )
      end

      # The first 「…」 in the heading (names may contain ～), else the heading itself.
      def event_name(heading)
        heading[/「(.+?)」/, 1] || heading
      end

      # Lines of the paragraphs after the 開催期間 <h4>, up to the next heading;
      # nil when the section has no such block.
      def period_lines(section)
        start = section.nodes.index { |node| heading?(node) && text_of(node).match?(PERIOD_HEADINGS) }
        return nil unless start

        section.nodes.drop(start + 1)
               .take_while { |node| !heading?(node) }
               .select(&:element?)
               .flat_map { |node| lines_of(node) }
               .reject(&:empty?)
      end

      def announces_event?(heading)
        heading.include?('「') && heading.match?(/開催/)
      end

      def kind_for(heading)
        KIND_PATTERNS.find { |pattern, _| heading.match?(pattern) }&.last
      end

      # → [boss element, advantaged element]. The record's element is the boss's
      # (what events and gw_events store); a post may name either side, and one
      # is derived from the other. Warns when the two named sides don't fit.
      def elements(body, name)
        enemy = enemy_element(body)
        advantage = advantage_element(body)
        if enemy && advantage && Normalization.advantage_for(enemy) != advantage
          @warnings << "#{name}: boss element #{enemy} doesn't match advantage element #{advantage}"
        end
        boss = enemy || Normalization.boss_for(advantage)
        [boss, advantage || Normalization.advantage_for(boss)]
      end

      # 「ボスとして土属性の…が登場」 or 「ボスは土属性」
      def enemy_element(body)
        Normalization::JA_ELEMENTS[body[/ボス(?:として|は)(.)属性/, 1]]
      end

      # 「風属性の編成を強化して」 / 「火属性有利」
      def advantage_element(body)
        Normalization::JA_ELEMENTS[body[/(.)属性(?:の編成を強化|有利)/, 1]]
      end

      def first_image(section)
        section.nodes.each do |node|
          next unless node.element?

          img = node.name == 'img' ? node : node.at_css('img')
          return img['src'] if img && img['src'].present?
        end
        nil
      end

      def parse_endpoint(text)
        match = text.strip.match(ENDPOINT)
        return nil unless match && match[:hour] && match[:rest].match?(ALLOWED_REST)

        { year: match[:year]&.to_i, month: match[:month].to_i, day: match[:day].to_i,
          hour: match[:hour].to_i, minute: match[:minute].to_i }
      end

      # A date written without a year belongs to the issue's year, except across
      # the new year: a December issue's January dates are next year's, and a
      # January issue's December dates are last year's.
      def infer_year(date_month, issue_year, issue_month)
        return issue_year + 1 if issue_month >= 11 && date_month <= 2
        return issue_year - 1 if issue_month <= 2 && date_month >= 11

        issue_year
      end

      # Hours past 23 (e.g. 25:00) roll into the next day.
      def build_time(year, point)
        return nil if point[:minute] > 59 || point[:hour] > 47
        return nil unless Date.valid_date?(year, point[:month], point[:day])

        Normalization.jst.local(year, point[:month], point[:day]) + point[:hour].hours + point[:minute].minutes
      end

      def heading?(node)
        node.element? && node.name.match?(/\Ah[1-6]\z/)
      end

      def text_of(node)
        node.text.gsub(/[[:space:]]+/, ' ').strip
      end

      def lines_of(node)
        copy = node.dup
        copy.css('br').each { |br| br.replace("\n") }
        copy.text.split("\n").map { |line| line.gsub(/[[:space:]]+/, ' ').strip }
      end
    end
  end
end
