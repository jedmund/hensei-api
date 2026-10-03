# frozen_string_literal: true

require 'securerandom'
require 'digest'
module GachaSimulation
  class Engine
    VERSION = '1.0.0'
    # Draw runs up to this size also report the identity of each SSR in the
    # order it was drawn; larger runs report aggregate counts only.
    SSR_ORDER_LIMIT = 10_000
    ASSUMPTIONS = [
      'Hypothetical catalogue pool, not a current banner; Zodiac rotations and spark exchanges excluded',
      'Inferred category shares: R 12:42:25; SR 5:6:4; SSR weapons:summons 11:4',
      'Guaranteed slots preserve SSR rates and scale SR category shares to the remaining budget',
      'Selected-gala limited residual weapons use weight 2; custom SSR percentages deduct from category budgets'
    ].freeze
    def initialize(compiled, seed = nil)
      @compiled = compiled
      @config = compiled.fetch('config')
      @seed = seed.nil? ? SecureRandom.hex(16) : seed.to_s
      raise ValidationError, 'Seed must contain 1–128 characters' unless (1..128).cover?(@seed.size)

      @random = Random.new(Digest::SHA256.hexdigest(@seed).to_i(16))
    end

    def draw(count)
      counts = Hash.new(0)
      ordered = []
      ssr_order = []
      totals = { 'R' => 0, 'SR' => 0, 'SSR' => 0 }
      ordinary = cumulative('ordinary')
      guaranteed = cumulative('guaranteed')
      count.times do |i|
        distribution = @config['purchase'] == 'ten' && ((i + 1) % 10).zero? ? guaranteed : ordinary
        value = @random.rand
        item = (distribution.bsearch { |entry| entry[0] > value } || distribution.last)[1]
        counts[item['identity']] += 1
        totals[%w[R SR SSR][item['rarity'] - 1]] += 1
        ordered << item if count <= 300
        ssr_order << item['identity'] if item['rarity'] == 3 && count <= SSR_ORDER_LIMIT
      end
      items = @compiled['ordinary'].map { |e| e['item'] }.uniq { |i| i['identity'] }
      result = { 'draws' => count.to_s, 'totals' => totals.transform_values(&:to_s), 'ordered' => count <= 300 ? ordered : nil,
                 'ssr_order' => count <= SSR_ORDER_LIMIT ? ssr_order : nil,
                 'items' => items.filter_map { |item| item.merge('count' => counts[item['identity']].to_s) if counts[item['identity']].positive? } }
      metadata.merge(result).merge('cost' => ExchangeRate.cost(count))
    end

    def target(operation, input)
      identity = Configuration.identity(input['target'])
      copies = Configuration.integer(input.fetch('copies', 1), 'copies', max: 1000)
      p = probability('ordinary', identity)
      g = probability('guaranteed', identity)
      raise ValidationError, 'Target unavailable or has zero probability' unless p.positive? || (@config['purchase'] == 'ten' && g.positive?)

      if operation == 'until'
        result = Probability.waiting(@random, p, g, copies, @config['purchase'])
      else
        count = self.class.draw_count(input, @config, max: 1_000_000_000_000)
        comparison = input.fetch('comparison', 'at_least')
        raise ValidationError, 'Comparison must be exactly or at_least' unless %w[exactly at_least].include?(comparison)

        slots = @config['purchase'] == 'ten' ? count / 10 : 0
        result = { 'draws' => count.to_s, 'comparison' => comparison,
                   'probability' => Probability.odds(count, p, g, copies, @config['purchase'], comparison),
                   'expected_copies' => ((count - slots) * p) + (slots * g),
                   'thresholds' => [50, 90, 95].to_h { |level|
                     [level.to_s, Probability.threshold(p, g, copies, @config['purchase'], level / 100.0)]
                   } }
      end
      metadata.merge(result).merge('target' => identity, 'requested_copies' => copies.to_s,
                                   'cost' => ExchangeRate.cost(result['draws']))
    end

    def self.draw_count(input, config, max: 1_000_000)
      count = Configuration.integer(input.fetch('draws', 300), 'draws', max: max)
      raise ValidationError, 'Ten-draw purchases require a multiple of 10' if config['purchase'] == 'ten' && count % 10 != 0

      count
    end

    private

    def metadata
      { 'seed' => @seed, 'configuration' => @config, 'catalogue_fingerprint' => @compiled['fingerprint'],
        'engine_version' => VERSION, 'ruby_version' => RUBY_VERSION, 'assumptions' => ASSUMPTIONS,
        'label' => 'Hypothetical catalogue simulation; spark exchanges excluded' }
    end

    def probability(distribution, identity)
      @compiled.fetch(distribution).find { |entry| entry['item']['identity'] == identity }&.fetch('probability').to_f
    end

    def cumulative(distribution)
      sum = 0.0
      @compiled.fetch(distribution).filter_map do |entry|
        probability = entry['probability'].to_f
        next unless probability.positive?

        sum += probability
        [sum, entry['item']]
      end
    end
  end
end
