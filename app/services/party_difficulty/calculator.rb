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
      weapons: [:awakening, :grid_weapon_bullets, { weapon: :weapon_series }],
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
    end

    def scoreable?
      enabled = enabled_components_by_name
      %w[weapon character summon].all? do |name|
        comp = enabled[name]
        comp.nil? || party_count_for(name) >= comp.min_count_to_score
      end
    end

    private

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
      when 'accessory' then @party.accessory_id.present?
      else false
      end
    end

    def component_breakdowns
      enabled_components_by_name.map do |name, comp|
        rules = @rules.select { |r| r.component == name }
        breakdown_for_component(name, comp, rules)
      end
    end

    def breakdown_for_component(name, comp, rules)
      present = data_for?(name)
      max_weight = rules.sum { |r| r.weight.to_f }

      if !present || rules.empty? || max_weight.zero?
        return {
          name: name,
          weight: comp.weight.to_f,
          present: present,
          raw_score: nil,
          weighted_score: nil,
          fired: []
        }
      end

      fired = rules.select { |r| safely_apply(r) }
      contribution = fired.sum { |r| r.weight.to_f }
      raw_score = contribution / max_weight
      weighted = raw_score * comp.weight.to_f

      {
        name: name,
        weight: comp.weight.to_f,
        present: true,
        raw_score: raw_score.round(4),
        weighted_score: weighted.round(4),
        fired: fired.map { |r| { id: r.id, name: r.name, rule_type: r.rule_type, weight: r.weight.to_f } }
      }
    end

    def safely_apply(rule)
      rule.applies_to?(@party)
    rescue StandardError => e
      Rails.logger.warn("[PartyDifficulty::Calculator] rule #{rule.id} (#{rule.rule_type}) raised: #{e.class}: #{e.message}")
      false
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
