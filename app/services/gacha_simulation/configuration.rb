# frozen_string_literal: true

require 'bigdecimal'
module GachaSimulation
  class Configuration
    MODES = { 'premium' => 1, 'classic' => 2, 'classic_ii' => 3, 'flash' => 4, 'legend' => 5, 'classic_iii' => 12 }.freeze
    SEASONS = { 'valentines' => 6, 'summer' => 7, 'halloween' => 8, 'holiday' => 9, 'formal' => 11 }.freeze
    # The game's current banner, with the rates it publishes (see Banner)
    CURRENT = 'current'

    def self.normalize(input)
      mode = input.fetch('mode', 'premium')
      season = input['season'].presence
      purchase = input.fetch('purchase', 'ten')
      validate_pool!(mode, season, purchase)
      rates = rateups(input.fetch('rateups', []))
      return { 'mode' => mode, 'season' => season, 'purchase' => purchase, 'rateups' => rates } unless mode == CURRENT

      current_banner(input, season, purchase, rates)
    end

    # The pool a draw comes from: a mode, an optional season and how draws are bought.
    def self.validate_pool!(mode, season, purchase)
      raise ValidationError, 'Unsupported mode' unless MODES.key?(mode) || mode == CURRENT
      raise ValidationError, 'Unsupported season' if season && !SEASONS.key?(season)
      raise ValidationError, 'Classic pools do not support seasons' if mode.start_with?('classic') && season
      raise ValidationError, 'Purchase must be singles or ten' unless %w[singles ten].include?(purchase)
    end

    # Custom SSR rates, sorted by identity, one per identity.
    def self.rateups(rates)
      raise ValidationError, 'Rate-ups must be an array of at most 1000 entries' unless rates.is_a?(Array) && rates.size <= 1000

      rates = rates.map do |entry|
        raise ValidationError, 'Invalid rate-up' unless entry.is_a?(Hash)

        percent = rateup_percent(entry['percent'])
        { 'identity' => identity(entry), 'percent' => percent.to_s('F') }
      end
      rates.sort_by! { |entry| entry['identity'] }
      raise ValidationError, 'Duplicate rate-up identity' unless rates.pluck('identity').uniq.size == rates.size

      rates
    end

    # A rate-up's percentage: a finite decimal from 0 to 100 that survives conversion to a Float.
    def self.rateup_percent(value)
      text = value.to_s
      raise ValidationError, 'Use a finite decimal percentage' unless text.size <= 128 && text.match?(/\A\d+(?:\.\d+)?(?:[eE][+-]?\d{1,3})?\z/)

      rate = BigDecimal(text, exception: false)
      raise ValidationError, 'Percentages must be finite and nonnegative' unless rate&.finite? && rate >= 0 && rate <= 100

      raise ValidationError, 'Percentage too small to represent' if rate.positive? && (rate / 100).to_f.zero?

      rate
    end

    # The game's current banner takes its rates from the game, so it has no seasons or rate-ups.
    def self.current_banner(input, season, purchase, rates)
      raise ValidationError, 'The current banner has no seasons' if season
      raise ValidationError, "The current banner's rates come from the game" if rates.any?

      banner = input['banner'].presence&.to_s
      raise ValidationError, 'Invalid banner id' if banner && !banner.match?(/\A\d{1,12}\z/)

      { 'mode' => CURRENT, 'season' => nil, 'purchase' => purchase, 'rateups' => [], 'banner' => banner }
    end
    private_class_method :validate_pool!, :rateups, :rateup_percent, :current_banner

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
