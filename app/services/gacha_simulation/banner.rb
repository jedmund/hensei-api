# frozen_string_literal: true

require 'bigdecimal'
module GachaSimulation
  # A stored game banner's rates, as the simulator's distributions. The game
  # truncates each item's displayed percentage, so a rarity's items fall a
  # little short of its stated total; the shortfall is shared equally between
  # them, which keeps each item's rate within the truncation of what's shown.
  # Items missing from our catalogue are left out, and their share goes to the
  # rest of their rarity the same way.
  class Banner
    LOCK = Mutex.new
    PRECISION = 40

    class << self
      # The banner a game id names, or the current one
      def load(game_id = nil)
        record = game_id ? GachaBanner.find_by(game_id: game_id.to_s) : GachaBanner.current
        raise ValidationError, (game_id ? 'Unknown banner' : 'No banner rates yet') unless record

        LOCK.synchronize do
          key = [record.id, record.fetched_at.to_f]
          @cache = { key => new(record) } unless @cache&.key?(key)
          @cache[key]
        end
      end

      # How many of the banner's items aren't in our catalogue
      def unmatched(record)
        ids = record.rates.where(tab: 1).pluck(:reward_id)
        ids.size - Weapon.where(granblue_id: ids).distinct.count(:granblue_id) -
          Summon.where(granblue_id: ids).distinct.count(:granblue_id)
      end
    end

    def initialize(record)
      @record = record
      @rarity_rates = record.rarity_rates
      @rates = record.rates.pluck(:tab, :reward_id, :rarity, :percent, :rate_up).group_by(&:first)
    end

    def info
      Catalogue.deep_freeze({ 'game_id' => @record.game_id, 'name' => @record.name,
                              'starts_at' => @record.starts_at.iso8601, 'ends_at' => @record.ends_at.iso8601,
                              'fetched_at' => @record.fetched_at.iso8601, 'live' => @record.live?,
                              'ssr_rate' => @rarity_rates.fetch('1').fetch('3') })
    end

    def reward_ids
      @rates.fetch(1).map { |row| row[1] }
    end

    # The displayed percentages of the banner's rate-ups, by reward id
    def rateups
      @rates.fetch(1).filter_map { |_, id, _, percent, rate_up| [id, percent.to_s('F')] if rate_up }.to_h
    end

    # [{ 'item', 'probability' }] for the ordinary draw or the 10-part's
    # guaranteed slot, from the catalogue's items
    def distribution(items, guaranteed)
      by_id = items.group_by { |item| item['granblue_id'] }.transform_values(&:first)
      tab = guaranteed ? guaranteed_tab : [@rarity_rates.fetch('1'), @rates.fetch(1)]
      rarities, rows = tab
      rarities.flat_map do |rarity, total|
        matched = rows.select { |row| row[2] == rarity.to_i && by_id.key?(row[1]) }
        shown = matched.sum { |row| row[3] }
        raise ValidationError, 'Catalogue incomplete: no catalogue items for a banner rarity' unless shown.positive?

        target = BigDecimal(total) * 100
        gap = (target - shown).div(matched.size, PRECISION)
        matched.map do |row|
          # Shown rates over the stated total (rounded, not truncated) scale down
          percent = gap.negative? ? (target * row[3]).div(shown, PRECISION) : row[3] + gap
          { 'item' => by_id.fetch(row[1]), 'probability' => (percent / 100).to_s('F') }
        end
      end
    end

    private

    # The game publishes the guaranteed slot as tab 2. Without it, the slot
    # keeps the ordinary SSR rate and gives the rest to SRs.
    def guaranteed_tab
      return [@rarity_rates.fetch('2'), @rates.fetch(2)] if @rates.key?(2) && @rarity_rates.key?('2')

      ssr = @rarity_rates.fetch('1').fetch('3')
      [{ '3' => ssr, '2' => (1 - BigDecimal(ssr)).to_s('F') }, @rates.fetch(1).reject { |row| row[2] == 1 }]
    end
  end
end
