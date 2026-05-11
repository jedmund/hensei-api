class SeedEndgameWeaponTierRules < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  # Endgame weapon tiers based on user-supplied ranking:
  #   Destroyer ULB > Destroyer FLB > Trans5 Dark Opus ≈ Celestial ULB Awak5
  #   > Celestial ULB > Trans3 Dark Opus ≈ Celestial FLB ≈ Draconic Providence
  #
  # All rules fire on "at least" thresholds so a Destroyer ULB also triggers
  # the FLB rule — the higher tier just adds more weight.
  def up
    return unless ActiveRecord::Base.connection.table_exists?(:difficulty_rules)

    rules.each do |attrs|
      DifficultyRule.find_or_create_by!(name: attrs[:name]) do |r|
        r.assign_attributes(attrs.merge(active: true))
      end
    end

    # Bump the existing Providence/Draconic rule up to weight 3.0 so it
    # aligns with the new tier ladder (Trans3 Dark Opus / Celestial FLB).
    providence = DifficultyRule.find_by(name: 'Providence/Draconic weapons')
    providence&.update!(weight: 3.0)
  end

  def down
    DifficultyRule.where(name: rules.map { |r| r[:name] }).delete_all
  end

  private

  def rules
    [
      { name: 'Destroyer weapon FLB',                  component: 'weapon',
        rule_type: 'weapon_tier_match', weight: 5.0,
        params: { 'series_slugs' => ['destroyer'], 'min_uncap_level' => 4 } },
      { name: 'Destroyer weapon ULB',                  component: 'weapon',
        rule_type: 'weapon_tier_match', weight: 6.0,
        params: { 'series_slugs' => ['destroyer'], 'min_uncap_level' => 5 } },

      { name: 'Trans3 Dark Opus weapon',               component: 'weapon',
        rule_type: 'weapon_tier_match', weight: 3.0,
        params: { 'series_slugs' => ['dark-opus'], 'min_transcendence_step' => 3 } },
      { name: 'Trans5 Dark Opus weapon',               component: 'weapon',
        rule_type: 'weapon_tier_match', weight: 4.0,
        params: { 'series_slugs' => ['dark-opus'], 'min_transcendence_step' => 5 } },

      { name: 'Celestial weapon FLB',                  component: 'weapon',
        rule_type: 'weapon_tier_match', weight: 3.0,
        params: { 'series_slugs' => ['celestial'], 'min_uncap_level' => 4 } },
      { name: 'Celestial weapon ULB',                  component: 'weapon',
        rule_type: 'weapon_tier_match', weight: 3.5,
        params: { 'series_slugs' => ['celestial'], 'min_uncap_level' => 5 } },
      { name: 'Celestial weapon ULB + Awakening 5+',   component: 'weapon',
        rule_type: 'weapon_tier_match', weight: 4.0,
        params: { 'series_slugs' => ['celestial'], 'min_uncap_level' => 5,
                  'min_awakening_level' => 5 } },

      # Sits below Celestial — moderately rare but easier to assemble.
      { name: 'Superlative weapon',                    component: 'weapon',
        rule_type: 'weapon_tier_match', weight: 2.5,
        params: { 'series_slugs' => ['superlative'] } },

      # Tier-equivalent to Trans5 Dark Opus.
      { name: 'Illustrious weapon',                    component: 'weapon',
        rule_type: 'weapon_tier_match', weight: 4.0,
        params: { 'series_slugs' => ['illustrious'] } }
    ]
  end
  # rubocop:enable Metrics/MethodLength
end
