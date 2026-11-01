# frozen_string_literal: true

require 'json'

module PartyDifficulty
  ##
  # Offline calibration harness for the difficulty ruleset. Scores every
  # eligible party against a ruleset held in memory (never saved), so
  # candidate values can be compared against the live ruleset before they go
  # through the draft workflow.
  #
  # A ruleset file is the JSON written by `Calibration.export`:
  #
  #   {
  #     "components": [{ "name": "weapon", "weight": 3.0, "target_max": null, ... }],
  #     "rules":      [{ "id": "…", "name": "…", "component": "weapon", "rule_type": "…",
  #                      "weight": 30.0, "params": { … }, "active": true }],
  #     "tiers":      [{ "slug": "casual", "name": "Casual", "min_score": 0, "max_score": 24.99 }]
  #   }
  #
  #   ruleset = PartyDifficulty::Calibration::Ruleset.from_file('candidate.json')
  #   results = PartyDifficulty::Calibration.new(ruleset).score_all
  class Calibration
    PartyResult = Struct.new(:party_id, :shortcode, :name, :score, :tier, :tier_slug, :breakdown, keyword_init: true)

    ##
    # An in-memory ruleset built from unsaved records, so validations and
    # callbacks (including the ruleset version bump) never run.
    class Ruleset
      attr_reader :components, :rules, :tiers

      UUID_FORMAT = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/

      def self.current
        new(
          components: DifficultyComponent.order(:name).map { |c| component_hash(c) },
          rules: DifficultyRule.order(:component, weight: :desc, name: :asc).map { |r| rule_hash(r) },
          tiers: Difficulty.ordered.map { |d| tier_hash(d) }
        )
      end

      def self.from_file(path)
        data = JSON.parse(File.read(path))
        new(components: data.fetch('components'), rules: data.fetch('rules'), tiers: data.fetch('tiers'))
      end

      def self.component_hash(comp)
        {
          'name' => comp.name,
          'weight' => comp.weight.to_f,
          'target_max' => comp.target_max&.to_f,
          'min_count_to_score' => comp.min_count_to_score,
          'enabled' => comp.enabled
        }
      end

      def self.rule_hash(rule)
        {
          'id' => rule.id,
          'name' => rule.name,
          'component' => rule.component,
          'rule_type' => rule.rule_type,
          'weight' => rule.weight.to_f,
          'params' => rule.params || {},
          'active' => rule.active
        }
      end

      def self.tier_hash(tier)
        {
          'slug' => tier.slug,
          'name' => tier.name,
          'min_score' => tier.min_score.to_f,
          'max_score' => tier.max_score.to_f
        }
      end

      def initialize(components:, rules:, tiers:)
        @components = components
        @rules = rules
        @tiers = tiers
      end

      def to_h
        { 'components' => components, 'rules' => rules, 'tiers' => tiers }
      end

      def component_records
        @component_records ||= components.map do |c|
          DifficultyComponent.new(c.slice('name', 'weight', 'target_max', 'min_count_to_score', 'enabled'))
        end
      end

      # Rules added in a candidate file have no database id yet. The id column
      # is a UUID, so a placeholder like "new-gacha-weapons" would be cast to
      # nil; give those a stable UUID derived from the name instead.
      def rule_records
        @rule_records ||= rules.select { |r| r.fetch('active', true) }.map do |r|
          DifficultyRule.new(r.slice('name', 'component', 'rule_type', 'weight', 'params').merge('id' => rule_id(r)))
        end
      end

      def rule_id(rule)
        id = rule['id'].to_s
        id.match?(UUID_FORMAT) ? id : Digest::UUID.uuid_v5(Digest::UUID::OID_NAMESPACE, "difficulty-rule:#{rule['name']}")
      end

      def tier_records
        @tier_records ||= tiers.sort_by { |t| t['min_score'].to_f }.map do |t|
          Difficulty.new(t.slice('slug', 'name', 'min_score', 'max_score'))
        end
      end

      # Same eligibility as SweepJob: the thresholds of the enabled primary
      # components.
      def min_counts
        enabled = components.select { |c| c['enabled'] }.index_by { |c| c['name'] }
        %w[weapon character summon].to_h { |name| [name, enabled.dig(name, 'min_count_to_score').to_i] }
      end
    end

    def self.export(path)
      File.write(path, "#{JSON.pretty_generate(Ruleset.current.to_h)}\n")
    end

    BATCH_SIZE = 200

    def initialize(ruleset)
      @ruleset = ruleset
    end

    def eligible_scope
      counts = @ruleset.min_counts
      Party.where('weapons_count >= ? AND characters_count >= ? AND summons_count >= ?',
                  counts['weapon'], counts['character'], counts['summon'])
    end

    # Scores every eligible party. Pass `party_ids` to score a fixed sample.
    def score_all(party_ids: nil)
      scope = party_ids ? eligible_scope.where(id: party_ids) : eligible_scope
      results = []
      scope.includes(eager_load).find_in_batches(batch_size: BATCH_SIZE) do |batch|
        batch.each { |party| results << score(party) }
      end
      results.compact
    end

    def score(party)
      result = Calculator.new(
        party,
        rules: @ruleset.rule_records,
        components: @ruleset.component_records,
        difficulties: @ruleset.tier_records,
        ruleset_version: 0
      ).call
      return nil unless result.scoreable

      PartyResult.new(
        party_id: party.id,
        shortcode: party.shortcode,
        name: party.name,
        score: result.score.to_f,
        tier: result.difficulty&.name,
        tier_slug: result.difficulty&.slug,
        breakdown: result.breakdown
      )
    end

    private

    def eager_load
      Calculator::EAGER_LOAD.map { |key, nested| nested.any? ? { key => nested } : key }
    end
  end
end
