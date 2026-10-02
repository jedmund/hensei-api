# frozen_string_literal: true

module GachaSimulation
  class Compiler
    SHARES = { 1 => { 'characterWeapon' => 12, 'weapon' => 42, 'summon' => 25 },
               2 => { 'characterWeapon' => 5, 'weapon' => 6, 'summon' => 4 } }.freeze
    EPSILON = BigDecimal('1e-24')

    def initialize(snapshot, config)
      @snapshot = snapshot
      @config = JSON.parse(JSON.generate(config))
      @items = snapshot.fetch('items').select { |item| Configuration.eligible?(item, config) }.uniq { |i| i['identity'] }
      @ssr = BigDecimal(%w[flash legend].include?(config['mode']) ? '0.06' : '0.03')
      @featured = config['rateups'].to_h do |rateup|
        item = @items.find { |i| i['identity'] == rateup['identity'] }
        raise ValidationError, 'Rate-up must be an eligible SSR item' unless item && item['rarity'] == 3

        [item['identity'], BigDecimal(rateup['percent']) / 100]
      end
      raise ValidationError, 'Custom rates exceed SSR budget' if @featured.values.sum > @ssr
    end

    def compile
      Catalogue.deep_freeze({ 'fingerprint' => @snapshot['fingerprint'], 'catalogue_loaded_at' => @snapshot['loaded_at'],
        'config' => @config, 'ordinary' => distribution(false), 'guaranteed' => distribution(true) })
    end

    private

    def distribution(guaranteed)
      budgets = { 1 => guaranteed ? BigDecimal('0') : BigDecimal('0.85') - @ssr,
                  2 => guaranteed ? 1 - @ssr : BigDecimal('0.15'), 3 => @ssr }
      result = budgets.flat_map do |rarity, budget|
        pool = @items.select { |i| i['rarity'] == rarity }
        rarity == 3 ? ssr_entries(pool, budget) : lower_entries(pool, rarity, budget)
      end
      total = result.sum { |entry| BigDecimal(entry['probability']) }
      raise ValidationError, 'Distribution does not conserve probability' if (total - 1).abs > EPSILON

      result
    end

    def lower_entries(pool, rarity, budget)
      shares = SHARES.fetch(rarity)
      shares.flat_map do |category, share|
        members = pool.select { |i| i['category'] == category }
        allocation = budget * share / shares.values.sum
        require_pool!(members, allocation)
        members.map { |item| entry(item, allocation / members.size) }
      end
    end

    def ssr_entries(pool, budget)
      residual = pool.reject { |item| @featured.key?(item['identity']) }
      allocations = %w[weapon summon].to_h do |category|
        featured = pool.select { |i| ssr_category(i) == category }.sum { |i| @featured.fetch(i['identity'], 0) }
        [category, [(budget * (category == 'weapon' ? 11 : 4) / 15) - featured, 0].max]
      end
      remaining = budget - @featured.values.sum
      result = pool.filter_map { |item| entry(item, @featured[item['identity']]) if @featured.key?(item['identity']) }
      allocations.each do |category, allocation|
        members = residual.select { |i| ssr_category(i) == category }
        amount = allocations.values.sum.positive? ? remaining * allocation / allocations.values.sum : BigDecimal('0')
        require_pool!(members, amount)
        total_weight = members.sum { |i| weight(i) }
        result.concat(members.map { |i| entry(i, amount * weight(i) / total_weight) })
      end
      result
    end

    def ssr_category(item)
      item['category'] == 'summon' ? 'summon' : 'weapon'
    end

    def weight(item)
      return 1 unless item['drawable_type'] == 'Weapon' && %w[flash legend].include?(@config['mode'])

      item['promotions'].include?(Configuration::MODES.fetch(@config['mode'])) && !item['promotions'].include?(1) ? 2 : 1
    end

    def require_pool!(members, budget)
      raise ValidationError, 'Catalogue incomplete: empty probability category' if budget > EPSILON && members.empty?
    end

    def entry(item, probability)
      { 'item' => item, 'probability' => probability.to_s('F') }
    end
  end
end
