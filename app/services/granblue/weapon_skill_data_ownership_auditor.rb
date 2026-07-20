# frozen_string_literal: true

module Granblue
  # Checks that weapon_skill_data, weapon_skill_effects, and weapon_skill_boost_types
  # keep their ownership boundaries. This runs against the checked-in JSON snapshots so
  # it can catch data-shape mistakes before import.
  class WeaponSkillDataOwnershipAuditor
    Finding = Struct.new(:severity, :code, :message, :context, keyword_init: true)
    Result = Struct.new(:ok, :findings, keyword_init: true) do
      def ok?
        ok
      end
    end

    INTENTIONAL_NULL_EFFECTS = {
      ["Blow", "bonus_elem_dmg", "bonus_dmg", nil] => "source_gap",
      ["Marvel", "skill_dmg_supp", "supplemental_cap", nil] => "cap_formula_only"
    }.freeze

    TABLE_VALUED_SCALING_KINDS = %w[specialty_scaled].freeze
    DOCUMENTATION_SCALING_KINDS = %w[documentation].freeze

    def self.run(root: Rails.root)
      new(root: root).run
    end

    def initialize(root: Rails.root)
      @root = Pathname(root)
      @findings = []
    end

    def run
      load_rows
      check_boost_type_registry
      check_count_bases
      check_effect_value_ownership
      check_duplicate_numeric_owners
      Result.new(ok: errors.empty?, findings: @findings)
    end

    private

    def load_rows
      @data_rows = JSON.parse(File.read(@root.join("data", "weapon_skill_data.json")))
      @boost_type_rows = JSON.parse(File.read(@root.join("data", "weapon_skill_boost_types.json")))
      payload = JSON.parse(File.read(@root.join("data", "weapon_skill_effects.json")))
      @effect_rows = payload.is_a?(Hash) ? payload.fetch("effects") : payload
      @boost_types = @boost_type_rows.index_by { |r| r.fetch("key") }
      @data_keys = @data_rows.to_set { |r| [r.fetch("modifier"), r.fetch("boost_type")] }
    end

    def check_boost_type_registry
      used_boost_types = (@data_rows + @effect_rows).filter_map { |r| r["boost_type"] }.uniq
      used_boost_types.sort.each do |boost_type|
        next if @boost_types.key?(boost_type)

        add(:error, "unregistered_boost_type",
            "Boost type is emitted by weapon-skill data/effects but missing from weapon_skill_boost_types.",
            boost_type: boost_type)
      end
    end

    def check_effect_value_ownership
      @effect_rows.each do |effect|
        if table_valued_effect?(effect)
          check_table_valued_effect(effect)
          next
        end
        next if curve_valued_effect?(effect)
        next if documentation_effect?(effect)

        next unless effect["value"].nil?

        key = effect_key(effect)
        unless INTENTIONAL_NULL_EFFECTS.key?(key)
          add(:error, "unclassified_null_effect",
              "Null effect value needs an explicit ownership classification before it can be trusted.",
              context_for(effect))
        end

        check_stranded_null_cap(effect)
      end
    end

    def check_count_bases
      @effect_rows.each do |effect|
        basis = effect["count_basis"]
        if basis.present? && !GridDamage::GridComposition.valid_count_basis?(basis)
          add(:error, "invalid_count_basis",
              "Effect count_basis must use canonical GridComposition count semantics.",
              context_for(effect).merge(count_basis: basis))
        end

        condition = effect["condition"]
        unless GridDamage::GridComposition.valid_count_condition?(condition)
          add(:error, "invalid_count_condition",
              "Count conditions must use canonical positive thresholds without legacy flags.",
              context_for(effect))
        end
        next unless condition.is_a?(Hash) && condition["type"] == "count_basis_gte"

        condition_basis = condition["basis"]
        next if GridDamage::GridComposition.valid_count_basis?(condition_basis)

        add(:error, "invalid_condition_count_basis",
            "count_basis_gte condition must use a canonical GridComposition count basis.",
            context_for(effect).merge(count_basis: condition_basis))
      end
    end

    def check_table_valued_effect(effect)
      specialties = effect.dig("condition", "specialties")
      return if specialties.is_a?(Hash) && specialties.values.any?

      add(:error, "invalid_table_valued_effect",
          "Table-valued scaling kind must carry its lookup table in condition.specialties.",
          context_for(effect))
    end

    def check_stranded_null_cap(effect)
      cap = effect["total_cap"]
      return if cap.nil?
      return unless @data_keys.include?([effect.fetch("modifier"), effect.fetch("boost_type")])

      boost_type = @boost_types[effect.fetch("boost_type")]
      registry_cap = boost_type && boost_type["grid_cap"]
      return if registry_cap && BigDecimal(registry_cap.to_s) == BigDecimal(cap.to_s)

      add(:error, "stranded_null_effect_cap",
          "Null effect row carries a cap, but the numeric owner is weapon_skill_data. " \
          "Put the cap on weapon_skill_boost_types or move the value into weapon_skill_effects.",
          context_for(effect).merge(effect_total_cap: cap, registry_grid_cap: registry_cap))
    end

    def check_duplicate_numeric_owners
      @effect_rows.each do |effect|
        next if effect["value"].nil?
        next unless @data_keys.include?([effect.fetch("modifier"), effect.fetch("boost_type")])
        next if conditional_delta_effect?(effect)

        add(:error, "duplicate_numeric_owner",
            "Same modifier/boost_type has numeric rows in both weapon_skill_data and weapon_skill_effects.",
            context_for(effect))
      end
    end

    def table_valued_effect?(effect)
      TABLE_VALUED_SCALING_KINDS.include?(effect["scaling_kind"])
    end

    def curve_valued_effect?(effect)
      effect["scaling_kind"] == "weapon_skill_curve" && effect.dig("condition", "curve").is_a?(Hash)
    end

    def documentation_effect?(effect)
      DOCUMENTATION_SCALING_KINDS.include?(effect["scaling_kind"])
    end

    def conditional_delta_effect?(effect)
      effect["scaling_kind"] == "conditional_flat" && effect["condition"].present?
    end

    def effect_key(effect)
      [effect.fetch("modifier"), effect.fetch("boost_type"), effect.fetch("scaling_kind"), effect["key_slug"]]
    end

    def context_for(effect)
      {
        modifier: effect["modifier"],
        boost_type: effect["boost_type"],
        scaling_kind: effect["scaling_kind"],
        key_slug: effect["key_slug"],
        condition: effect["condition"]
      }.compact
    end

    def add(severity, code, message, context)
      @findings << Finding.new(severity: severity, code: code, message: message, context: context)
    end

    def errors
      @findings.select { |finding| finding.severity == :error }
    end
  end
end
