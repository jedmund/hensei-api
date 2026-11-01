# frozen_string_literal: true

module PartyDifficulty
  class Calibration
    ##
    # Writes a calibrated ruleset file to the canonical difficulty tables in
    # one transaction. Components match by name, tiers by slug, and rules by
    # id (falling back to name), so renamed rules keep their history. Rules
    # in the file that don't exist yet are created; rules in the database
    # that the file doesn't list are deactivated, never deleted.
    #
    # Each save bumps the ruleset version, so SweepJob rescores every party
    # on its next run.
    #
    #   PartyDifficulty::Calibration::Applier.new(Ruleset.from_file(path)).apply!
    class Applier
      COMPONENT_FIELDS = %w[weight target_max min_count_to_score enabled].freeze
      RULE_FIELDS = %w[name component rule_type weight params].freeze
      TIER_FIELDS = %w[name min_score max_score].freeze

      def initialize(ruleset)
        @ruleset = ruleset
      end

      def apply!
        ApplicationRecord.transaction do
          apply_components!
          apply_rules!
          apply_tiers!
        end
      end

      private

      def apply_components!
        @ruleset.components.each do |attrs|
          component = DifficultyComponent.find_by!(name: attrs['name'])
          component.assign_attributes(attrs.slice(*COMPONENT_FIELDS))
          component.save! if component.changed?
        end
      end

      def apply_rules!
        listed = @ruleset.rules.map do |attrs|
          rule = find_rule(attrs) || DifficultyRule.new(id: @ruleset.rule_id(attrs))
          rule.assign_attributes(attrs.slice(*RULE_FIELDS).merge('active' => attrs.fetch('active', true)))
          rule.save! if rule.new_record? || rule.changed?
          rule.id
        end

        DifficultyRule.where.not(id: listed).where(active: true).find_each { |rule| rule.update!(active: false) }
      end

      def find_rule(attrs)
        DifficultyRule.find_by(id: @ruleset.rule_id(attrs)) || DifficultyRule.find_by(name: attrs['name'])
      end

      # Moving several boundaries at once leaves gaps and overlaps between
      # saves, so check the final set up front and skip the per-row check.
      def apply_tiers!
        tiers = @ruleset.tiers.map do |attrs|
          tier = Difficulty.find_by!(slug: attrs['slug'])
          tier.assign_attributes(attrs.slice(*TIER_FIELDS))
          tier
        end

        others = Difficulty.where.not(id: tiers.map(&:id)).to_a
        errors = Difficulty.coverage_errors_for(tiers + others)
        raise ArgumentError, "ruleset tiers don't cover 0–100: #{errors.join('; ')}" if errors.any?

        Difficulty.with_coverage_validation_skipped do
          tiers.select(&:changed?).each(&:save!)
        end
      end
    end
  end
end
