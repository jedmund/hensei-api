# frozen_string_literal: true

module PartyDifficulty
  ##
  # Registry of all difficulty rule types.
  # Rule classes live under `app/services/party_difficulty/rules/`.
  module Rules
    # Order matters here only for the editor UI's grouping.
    REGISTRY = {
      'weapon_series_match'             => 'WeaponSeriesMatch',
      'weapon_seasonal_match'           => 'WeaponSeasonalMatch',
      'weapon_tier_match'               => 'WeaponTierMatch',
      'weapon_specific_match'           => 'WeaponSpecificMatch',
      'weapon_awakening_at_least'       => 'WeaponAwakeningAtLeast',
      'weapon_transcendence_at_least'   => 'WeaponTranscendenceAtLeast',
      'weapon_uncap_at_least'           => 'WeaponUncapAtLeast',
      'weapon_promotion_includes'       => 'WeaponPromotionIncludes',
      'weapon_ax_filled'                => 'WeaponAxFilled',
      'weapon_befoulment_filled'        => 'WeaponBefoulmentFilled',
      'weapon_release_within_days'      => 'WeaponReleaseWithinDays',
      'weapon_bullet_match'             => 'WeaponBulletMatch',
      'character_seasonal'              => 'CharacterSeasonal',
      'character_series_match'          => 'CharacterSeriesMatch',
      'character_perpetuity_ringed'     => 'CharacterPerpetuityRinged',
      'character_earring_at_least'      => 'CharacterEarringAtLeast',
      'character_transcendence_at_least' => 'CharacterTranscendenceAtLeast',
      'character_release_within_days'   => 'CharacterReleaseWithinDays',
      'summon_series_match'             => 'SummonSeriesMatch',
      'summon_uncap_at_least'           => 'SummonUncapAtLeast',
      'summon_transcendence_at_least'   => 'SummonTranscendenceAtLeast',
      'summon_release_within_days'      => 'SummonReleaseWithinDays',
      'job_row'                         => 'JobRow',
      'accessory_match'                 => 'AccessoryMatch',
      'mainhand_bullet_match'           => 'MainhandBulletMatch'
    }.freeze

    def self.registered_types
      REGISTRY.keys
    end

    def self.lookup(rule_type)
      class_name = REGISTRY[rule_type.to_s]
      return nil unless class_name

      "PartyDifficulty::Rules::#{class_name}".constantize
    end

    def self.build(rule_type, params)
      klass = lookup(rule_type)
      raise ArgumentError, "Unknown difficulty rule_type: #{rule_type}" unless klass

      klass.new(params)
    end

    def self.validate_params(rule_type, params)
      klass = lookup(rule_type)
      return ["Unknown rule_type: #{rule_type}"] unless klass

      klass.validate_params(params || {})
    end

    def self.component_for(rule_type)
      lookup(rule_type)&.component
    end

    def self.types_grouped_by_component
      REGISTRY.keys.group_by { |type| component_for(type) }
    end
  end
end
