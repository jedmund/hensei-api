# frozen_string_literal: true

require 'bigdecimal'
module GachaSimulation
  class Configuration
    MODES = { 'premium' => 1, 'classic' => 2, 'classic_ii' => 3, 'flash' => 4, 'legend' => 5, 'classic_iii' => 12 }.freeze
    SEASONS = { 'valentines' => 6, 'summer' => 7, 'halloween' => 8, 'holiday' => 9, 'formal' => 11 }.freeze

    def self.normalize(input)
      mode = input.fetch('mode', 'premium')
      season = input['season'].presence
      purchase = input.fetch('purchase', 'ten')
      raise ValidationError, 'Unsupported mode' unless MODES.key?(mode)
      raise ValidationError, 'Unsupported season' if season && !SEASONS.key?(season)
      raise ValidationError, 'Classic pools do not support seasons' if mode.start_with?('classic') && season
      raise ValidationError, 'Purchase must be singles or ten' unless %w[singles ten].include?(purchase)

      rates = input.fetch('rateups', [])
      raise ValidationError, 'Rate-ups must be an array of at most 1000 entries' unless rates.is_a?(Array) && rates.size <= 1000

      rates = rates.map do |entry|
        raise ValidationError, 'Invalid rate-up' unless entry.is_a?(Hash)

        text = entry['percent'].to_s
        raise ValidationError, 'Use a finite decimal percentage' unless text.size <= 128 && text.match?(/\A\d+(?:\.\d+)?(?:[eE][+-]?\d{1,3})?\z/)

        rate = BigDecimal(text, exception: false)
        raise ValidationError, 'Percentages must be finite and nonnegative' unless rate&.finite? && rate >= 0 && rate <= 100

        raise ValidationError, 'Percentage too small to represent' if rate.positive? && (rate / 100).to_f.zero?

        { 'identity' => identity(entry), 'percent' => rate.to_s('F') }
      end
      rates.sort_by! { |entry| entry['identity'] }
      raise ValidationError, 'Duplicate rate-up identity' unless rates.map { |r| r['identity'] }.uniq.size == rates.size

      { 'mode' => mode, 'season' => season, 'purchase' => purchase, 'rateups' => rates }
    end

    def self.identity(input)
      value = input.is_a?(Hash) ? input['identity'] : input
      unless value.is_a?(String) && value.match?(/\A(?:Weapon|Summon):[\da-f-]{36}\z/i)
        raise ValidationError,
              'Use a typed Weapon:UUID or Summon:UUID identity'
      end

      value
    end

    def self.integer(value, name, max:)
      raise ValidationError, "#{name} must be an integer from 1 to #{max}" unless value.to_s.match?(/\A\d{1,13}\z/) && (1..max).cover?(value.to_i)

      value.to_i
    end

    def self.eligible?(item, config)
      promotions = item.fetch('promotions')
      mode = config.fetch('mode')
      return promotions.include?(MODES.fetch(mode)) if mode.start_with?('classic')

      promotions.include?(1) || promotions.include?(MODES.fetch(mode)) ||
        (config['season'] && promotions.include?(SEASONS.fetch(config['season'])))
    end
  end
end
