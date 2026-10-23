# frozen_string_literal: true

require 'bigdecimal'
module GachaSimulation
  # Stores a banner from the game's own responses: its `/gacha/list` lineup
  # entry and its `/gacha/provision_ratio` tabs (1 is the ordinary draw, 2 the
  # 10-part's guaranteed SR or better). Importing a banner again replaces it.
  class BannerImport
    # The game's rarity names (in the account's language) and numbers, as our rarities
    RARITY_NAMES = { 'SSレア' => 3, 'Sレア' => 2, 'レア' => 1, 'SS Rare' => 3, 'S Rare' => 2, 'Rare' => 1 }.freeze
    RARITIES = { 4 => 3, 3 => 2, 2 => 1 }.freeze
    CATEGORIES = { 0 => 'characterWeapon', 1 => 'weapon', 2 => 'summon' }.freeze
    TOKYO = 'Asia/Tokyo'
    # "2026/10/9 19:00" in Japanese
    JAPANESE_TIME = %r{\A(?<year>\d{4})/(?<month>\d{1,2})/(?<day>\d{1,2}) (?<hour>\d{1,2}):(?<minute>\d{2})\z}
    # "7 p.m., Oct 9, 2026 (JST)" or "6:59 p.m., Oct 12, 2026 (JST)" in English
    ENGLISH_TIME = /\A(?<hour>\d{1,2})(?::(?<minute>\d{2}))? (?<half>[ap])\.m\., (?<month>[A-Z][a-z]+)\.? (?<day>\d{1,2}), (?<year>\d{4}) \(JST\)\z/

    def self.call(payload)
      new(payload).call
    end

    def initialize(payload)
      raise ValidationError, 'Expected a banner and its rate tabs' unless payload.is_a?(Hash)

      @lineup = payload['banner']
      @tabs = payload['tabs']
      raise ValidationError, 'Expected a banner' unless @lineup.is_a?(Hash)
      raise ValidationError, 'Expected rate tabs' unless @tabs.is_a?(Hash) && @tabs.key?('1')
    end

    def call
      game_id = @lineup['id'].to_s
      raise ValidationError, 'Invalid banner id' unless game_id.match?(/\A\d{1,12}\z/)

      tabs = @tabs.slice('1', '2').to_h { |tab, data| [tab.to_i, parse_tab(data)] }
      now = Time.current
      banner = GachaBanner.transaction do
        record = GachaBanner.lock.find_or_initialize_by(game_id: game_id)
        record.update!(name: @lineup['name'].to_s.first(200).presence, starts_at: time(@lineup['service_start']),
                       ends_at: time(@lineup['service_end']) + 1.minute, fetched_at: now,
                       rarity_rates: tabs.to_h { |tab, data| [tab.to_s, data[:rarities]] })
        record.rates.delete_all
        rows = tabs.flat_map do |tab, data|
          data[:items].map { |item| item.merge(gacha_banner_id: record.id, tab: tab) }
        end
        GachaBannerRate.insert_all!(rows)
        record
      end
      { 'game_id' => banner.game_id, 'items' => banner.rates.where(tab: 1).count,
        'unmatched' => Banner.unmatched(banner) }
    end

    private

    def parse_tab(data)
      raise ValidationError, 'Invalid rate tab' unless data.is_a?(Hash) && data['ratio'].is_a?(Array) && data['appear'].is_a?(Array)

      rarities = data['ratio'].to_h do |entry|
        rarity = RARITY_NAMES[entry.is_a?(Hash) && entry['rare']]
        raise ValidationError, 'Unknown rarity' unless rarity

        [rarity.to_s, (percent(entry['ratio'].to_s.delete_suffix('%')) / 100).to_s('F')]
      end
      raise ValidationError, 'Rarity rates must total 100%' unless rarities.values.sum { |v| BigDecimal(v) } == 1

      items = data['appear'].flat_map { |group| parse_group(group) }
      raise ValidationError, 'Duplicate item in a rate tab' unless items.map { |i| i[:reward_id] }.uniq.size == items.size
      raise ValidationError, 'A stated rarity has no items' unless rarities.keys.all? { |r| items.any? { |i| i[:rarity] == r.to_i } }

      { rarities: rarities, items: items }
    end

    def parse_group(group)
      raise ValidationError, 'Invalid rate group' unless group.is_a?(Hash) && group['item'].is_a?(Array)

      rarity = RARITIES[group['rarity']]
      category = CATEGORIES[group['category']]
      raise ValidationError, 'Unknown rarity or category' unless rarity && category

      group['item'].map do |item|
        raise ValidationError, 'Invalid rate item' unless item.is_a?(Hash) && item['reward_id'].to_s.match?(/\A\d{10}\z/)

        { reward_id: item['reward_id'].to_s, rarity: rarity, category: category, percent: percent(item['drop_rate']),
          rate_up: item['incidence'].to_s == '1', name: item['name'].to_s.first(200).presence }
      end
    end

    def percent(value)
      text = value.to_s
      raise ValidationError, 'Invalid percentage' unless text.match?(/\A\d{1,3}(?:\.\d{1,6})?\z/)

      number = BigDecimal(text)
      raise ValidationError, 'Invalid percentage' if number > 100

      number
    end

    # The game's times are Tokyo time, in the account's language. A banner's
    # end is its last minute, so it's stored as the minute after.
    def time(value)
      text = value.to_s
      parts = text.match(JAPANESE_TIME) || text.match(ENGLISH_TIME)
      raise ValidationError, 'Invalid banner time' unless parts

      Time.find_zone!(TOKYO).local(parts[:year].to_i, month(parts[:month]), parts[:day].to_i, hour(parts),
                                   parts[:minute].to_i)
    rescue ArgumentError
      raise ValidationError, 'Invalid banner time'
    end

    def month(value)
      return value.to_i if value.match?(/\A\d+\z/)

      Date::ABBR_MONTHNAMES.index(value[0, 3]) || raise(ValidationError, 'Invalid banner time')
    end

    def hour(parts)
      hour = parts[:hour].to_i
      return hour unless parts.names.include?('half')
      raise ValidationError, 'Invalid banner time' unless hour.between?(1, 12)

      (hour % 12) + (parts[:half] == 'p' ? 12 : 0)
    end
  end
end
