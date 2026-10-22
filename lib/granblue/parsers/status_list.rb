# frozen_string_literal: true

module Granblue
  module Parsers
    # gbf.wiki's Module:StatusList, the data behind the wiki's {{status}} template, stored as a
    # Source row (kind wiki_status_list, D34; fetched by granblue:fetch_wiki_status_list or
    # Sources::FetchWikiStatusListJob). Tables `buffs`, `debuffs` and `effects` key entries by wiki
    # name; an entry either has its own `page` (a base status) or a `link` to its base entry, and
    # carries the game's exact display id (`status`, e.g. "1032_42") and description (`detail`).
    # `aliases` maps other wiki names onto entries. Without the row (a fresh database) the list is
    # empty and status names fall back to the heuristics (StatusName).
    #
    # resolve follows the module's own lookup (Module:Status fetchStatus): aliases, then buffs,
    # debuffs, effects, then each link, the first value seen winning. A status is its base entry
    # (where the links end); a linked entry ("Accuracy Lowered 2", "5% DMG Cut") is a variant of it.
    class StatusList
      KIND = 'wiki_status_list'
      KEY = 'Module:StatusList'
      TABLES = { 'buffs' => 'buff', 'debuffs' => 'debuff', 'effects' => 'special' }.freeze
      MAX_LINKS = 10
      MERGED_FIELDS = %w[status detail page].freeze

      # entry: the key found; base: the base entry's key; category: buff | debuff | field | special
      # (effects are instant effects: Charge Boost, Delay); status_id: the exact display id;
      # base_status_id: the base entry's own id; detail: the game's description (of the variant if it
      # has one; base_detail: the base's); page: the wiki article; label: the wiki's display name for
      # the base (its wiki_name without amount placeholders: "%a% Fire ATK Down" → "Fire ATK Down").
      Resolution = Struct.new(:entry, :base, :category, :status_id, :base_status_id, :detail, :base_detail, :page, :label,
                              keyword_init: true) do
        # The trailing number of a numbered variant ("Accuracy Lowered 2" → 2).
        def variant
          entry == base ? nil : entry[/ (\d+)\z/, 1]&.to_i
        end
      end

      class << self
        # The list from the stored row, re-read when its sha changes (refresh!: one query).
        def current
          @current ||= load
        end

        def refresh!
          return current if @pinned

          sha = Source.without_body.where(owner_type: nil, owner_id: nil, kind: KIND, key: KEY).pick(:sha256)
          @current = load if @current.nil? || @current.sha256 != sha
          @current
        end

        def reset!
          @current = nil
          @pinned = false
        end

        # For specs: a list from Lua source (empty by default), kept until reset!.
        def use(source = nil)
          @pinned = true
          @current = new(source)
        end

        delegate :resolve, :sha256, :missing?, to: :current

        private

        def load
          source = Source.fetch(nil, KIND, key: KEY)
          Rails.logger.warn "[STATUS_LIST] no #{KIND} source: status names use the fallbacks" if source.nil?
          new(source&.body, sha256: source&.sha256)
        end
      end

      class Invalid < StandardError; end

      # A fetched body is only stored when it parses, has buffs and debuffs, and every name in it
      # resolves (Sources::WikiStatusList). → the list, or StatusList::Invalid.
      def self.validate!(body)
        list = new(body)
        tables = list.instance_variable_get(:@tables)
        raise Invalid, 'no buffs or debuffs' if tables['buffs'].empty? || tables['debuffs'].empty?

        names = tables.values.flat_map(&:keys) + list.instance_variable_get(:@aliases).keys
        names.each { |name| list.resolve(name) }
        list
      rescue Invalid
        raise
      rescue StandardError => e
        raise Invalid, "#{e.class}: #{e.message}"
      end

      attr_reader :sha256

      def initialize(body, sha256: nil)
        @missing = body.nil?
        body ||= 'return {}'
        @sha256 = sha256 || (@missing ? nil : Digest::SHA256.hexdigest(body))
        data = LuaTable.parse(body)
        @tables = TABLES.keys.to_h { |table| [table, data.fetch(table, {})] }
        @aliases = data.fetch('aliases', {})
        build_indexes
      end

      def missing?
        @missing
      end

      # Every name the list knows (entries, aliases, page titles), normalized: the wiki's own spellings.
      def vocabulary
        @vocabulary ||= (@normalized.keys + @by_page.keys).to_set
      end

      def resolve(name)
        key = lookup_key(name.to_s.squish)
        key && chain(key)
      end

      private

      def build_indexes
        @normalized = {}
        [@aliases.keys, *@tables.values.map(&:keys)].each do |keys|
          keys.each { |key| @normalized[Status.normalize_name(key)] ||= key }
        end
        pages = Hash.new { |hash, page| hash[page] = [] }
        @tables.each_value do |entries|
          entries.each { |key, entry| pages[Status.normalize_name(entry['page'].to_s.split('#').first)] << key if entry['page'].present? }
        end
        @by_page = pages.select { |_, keys| keys.one? }.transform_values(&:first)
      end

      # The exact key, else the same name in another case or spacing, else the one base entry
      # whose wiki page has that title ("Charm" → Charmed, page Charm).
      def lookup_key(name)
        return name if entry(name) || @aliases.key?(name)

        normalized = Status.normalize_name(name)
        @normalized[normalized] || @by_page[normalized]
      end

      def entry(key)
        @tables.each { |table, entries| return [table, entries[key]] if entries.key?(key) }
        nil
      end

      # Follows aliases and links; every hop (alias or link) counts against MAX_LINKS, so a cycle in
      # the wiki's data ends instead of looping.
      def chain(key)
        found = nil
        values = {}
        hops = 0
        loop do
          while @aliases.key?(key)
            return found && finish(found, values) if (hops += 1) > MAX_LINKS

            key = @aliases[key]
          end
          table, data = entry(key)
          return found && finish(found, values) if data.nil?

          found ||= key
          MERGED_FIELDS.each { |field| values[field] ||= data[field].presence }
          values['base'] = key
          values['table'] = table
          values['base_data'] = data
          return finish(found, values) if data['link'].blank? || (hops += 1) > MAX_LINKS

          key = data['link']
        end
      end

      def finish(found, values)
        base = values['base_data'] || {}
        Resolution.new(entry: found, base: values['base'], category: category(values['table'], base),
                       status_id: values['status'], base_status_id: base['status'].presence,
                       detail: values['detail'] || plain(base['wiki_detail']),
                       base_detail: base['detail'].presence || plain(base['wiki_detail']), page: values['page'],
                       label: base['wiki_name'].to_s.gsub(/%\w+%/, '').squish.presence)
      end

      # wiki_detail is wikitext: [[Charge Bar]] → Charge Bar.
      def plain(text)
        text.to_s.gsub(/\[\[(?:[^\]|]*\|)?([^\]]*)\]\]/, '\\1').presence
      end

      def category(table, base)
        return 'field' if base['wiki_comment'].to_s.match?(/\[\[Field effect\]\]/i)

        TABLES[table]
      end
    end
  end
end
