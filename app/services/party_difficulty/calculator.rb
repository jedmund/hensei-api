# frozen_string_literal: true

module PartyDifficulty
  ##
  # Computes the difficulty score for a single Party.
  #
  # Pure function: does not persist anything. Use ScoreJob to compute and save.
  #
  #   result = PartyDifficulty::Calculator.new(party).call
  #   result.scoreable      # => true/false
  #   result.score          # => 0..100 (Float)
  #   result.difficulty     # => Difficulty record (or nil if no tier matches)
  #   result.breakdown      # => Hash with per-component fired-rule details
  #   result.ruleset_version
  class Calculator
    Result = Struct.new(:scoreable, :score, :difficulty, :breakdown, :ruleset_version, keyword_init: true)

    EAGER_LOAD = {
      weapons: [:awakening, :grid_weapon_bullets, { weapon: %i[weapon_series recruited_character] }],
      characters: [{ character: :character_series_records }],
      summons: [{ summon: :summon_series }],
      job: [],
      accessory: []
    }.freeze

    def self.eager_load_party(party_id)
      Party.includes(*EAGER_LOAD.keys.map { |k| EAGER_LOAD[k].any? ? { k => EAGER_LOAD[k] } : k }).find(party_id)
    end

    def initialize(party, rules: nil, components: nil, difficulties: nil, ruleset_version: nil)
      @party = party
      @rules = rules || DifficultyRule.active.to_a
      @components = components || DifficultyComponent.all.to_a
      @difficulties = difficulties || Difficulty.ordered.to_a
      @ruleset_version = ruleset_version || DifficultyConfig.current_version
    end

    def call
      return Result.new(scoreable: false, ruleset_version: @ruleset_version) unless scoreable?

      preload_series_caches!
      begin
        breakdowns = component_breakdowns
        composite = composite_score(breakdowns)
        tier = find_tier(composite)

        Result.new(
          scoreable: true,
          score: composite,
          difficulty: tier,
          breakdown: { components: breakdowns, score: composite, tier_id: tier&.id },
          ruleset_version: @ruleset_version
        )
      ensure
        clear_series_caches!
      end
    end

    def scoreable?
      enabled = enabled_components_by_name
      %w[weapon character summon].all? do |name|
        comp = enabled[name]
        comp.nil? || party_count_for(name) >= comp.min_count_to_score
      end
    end

    private

    SERIES_CACHE_KEYS = {
      'weapon' => :pd_weapon_series_cache,
      'character' => :pd_character_series_cache,
      'summon' => :pd_summon_series_cache
    }.freeze

    SERIES_MODELS = {
      'weapon' => 'WeaponSeries',
      'character' => 'CharacterSeries',
      'summon' => 'SummonSeries'
    }.freeze

    ##
    # Batches slug → id lookups for every *_series_match rule into one query
    # per series type, then stashes the results in thread-local storage so the
    # individual rule instances can read them instead of hitting the DB
    # separately. Cleared in `clear_series_caches!` after scoring completes.
    def preload_series_caches!
      %w[weapon character summon].each do |kind|
        slugs = collect_series_slugs("#{kind}_series_match")
        Thread.current[SERIES_CACHE_KEYS[kind]] = if slugs.empty?
                                                    {}
                                                  else
                                                    SERIES_MODELS[kind].constantize.where(slug: slugs).pluck(:slug, :id).to_h
                                                  end
      end
    end

    def clear_series_caches!
      SERIES_CACHE_KEYS.each_value { |key| Thread.current[key] = nil }
    end

    def collect_series_slugs(rule_type)
      @rules
        .select { |r| r.rule_type == rule_type }
        .flat_map { |r| Array(r.params&.[]('slugs')) }
        .map(&:to_s)
        .reject(&:empty?)
        .uniq
    end

    def enabled_components_by_name
      @enabled_components_by_name ||= @components.select(&:enabled).index_by(&:name)
    end

    def party_count_for(component_name)
      case component_name
      when 'weapon' then @party.weapons_count.to_i
      when 'character' then @party.characters_count.to_i
      when 'summon' then @party.summons_count.to_i
      else 0
      end
    end

    def data_for?(component_name)
      case component_name
      when 'weapon', 'character', 'summon' then party_count_for(component_name).positive?
      when 'job' then @party.job_id.present?
      when 'accessory' then accessory_data?
      else false
      end
    end

    # The "accessory" component covers the party's JobAccessory (manatura /
    # shield) plus rare bullets equipped on the mainhand, so the component is
    # considered present if either side has data.
    def accessory_data?
      return true if @party.accessory_id.present?

      mainhand = @party.weapons.to_a.find(&:mainhand)
      mainhand&.grid_weapon_bullets&.any? || false
    end

    def component_breakdowns
      enabled_components_by_name.map do |name, comp|
        rules = @rules.select { |r| r.component == name }
        breakdown_for_component(name, comp, rules)
      end
    end

    def breakdown_for_component(name, comp, rules)
      present = data_for?(name)

      if !present || rules.empty?
        return {
          name: name,
          weight: comp.weight.to_f,
          present: present,
          raw_score: nil,
          weighted_score: nil,
          fired: []
        }
      end

      contributions = rules.map { |rule| rule_contribution(rule) }
      max_weight = contributions.sum { |c| c[:max] }

      if max_weight.zero?
        return {
          name: name,
          weight: comp.weight.to_f,
          present: present,
          raw_score: nil,
          weighted_score: nil,
          fired: []
        }
      end

      fired = contributions.select { |c| c[:contribution].positive? }
      contribution_sum = fired.sum { |c| c[:contribution] }
      raw_score = (contribution_sum / max_weight).clamp(0.0, 1.0)
      weighted = raw_score * comp.weight.to_f

      {
        name: name,
        weight: comp.weight.to_f,
        present: true,
        raw_score: raw_score.round(4),
        weighted_score: weighted.round(4),
        fired: fired.flat_map { |c| fired_entries_for(c) }
      }
    end

    ##
    # Returns one or two fired entries for a rule that fired. Scaling rules
    # with more than one match split into a "base" row plus an "additional"
    # row so the UI can render them separately.
    def fired_entries_for(contribution)
      rule = contribution[:rule]
      count = contribution[:count]
      base = contribution[:base_weight]
      total = contribution[:contribution]

      base_entry = {
        id: rule.id,
        name: rule.name,
        rule_type: rule.rule_type,
        weight: base.round(2),
        match_count: 1,
        kind: 'base'
      }

      additional = total - base
      return [base_entry] unless contribution[:scale_by_count] && additional.positive?

      [
        base_entry,
        {
          id: "#{rule.id}-additional",
          name: rule.name,
          rule_type: rule.rule_type,
          weight: additional.round(2),
          match_count: count - 1,
          kind: 'additional'
        }
      ]
    end

    ##
    # Returns the actual + max contribution for a single rule, taking the
    # scale_by_count / max_count params and any per-match decay factors into
    # account.
    def rule_contribution(rule)
      impl = rule.implementation
      params = (rule.params || {}).with_indifferent_access
      factors = safely_factors(impl)
      count = factors.size
      min_count = impl.min_count
      weight = rule.weight.to_f

      scale = [true, 'true'].include?(params[:scale_by_count])
      max_count = params[:max_count].to_i
      max_count = 1 if max_count <= 0

      max_value = scale ? weight * max_count : weight

      if count < min_count
        return { rule: rule, count: count, contribution: 0.0, max: max_value,
                 base_weight: weight, scale_by_count: scale }
      end

      effective_factors = scale ? factors.first(max_count) : factors.first(1)
      contribution = weight * effective_factors.sum
      base_contribution = weight * (effective_factors.first || 0)

      {
        rule: rule,
        count: count,
        contribution: contribution,
        max: max_value,
        base_weight: base_contribution,
        scale_by_count: scale
      }
    end

    def safely_factors(impl)
      impl.match_factors(@party)
    rescue StandardError => e
      Rails.logger.warn("[PartyDifficulty::Calculator] rule raised: #{e.class}: #{e.message}")
      []
    end

    def composite_score(breakdowns)
      contributing = breakdowns.select { |b| b[:weighted_score] }
      return 0 if contributing.empty?

      weight_sum = contributing.sum { |b| b[:weight] }
      return 0 if weight_sum.zero?

      score_sum = contributing.sum { |b| b[:weighted_score] }
      ((score_sum / weight_sum) * 100).round(2)
    end

    def find_tier(score)
      @difficulties.find { |d| score >= d.min_score.to_f && score <= d.max_score.to_f }
    end
  end
end
