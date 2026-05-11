class MakeWeaponTiersExclusive < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  # Each weapon should fire exactly one tier rule. We previously relied on
  # "at least" thresholds plus stacking — a Trans5 Dark Opus weapon scored
  # both the Trans3 and Trans5 rules. Now we close the upper end of the
  # lower-tier rules and roll the stacked weight into the higher tier so
  # individual weapons score the same as before but only via one rule.
  def up
    return unless ActiveRecord::Base.connection.table_exists?(:difficulty_rules)

    # Drop the generic transcendence rules — series-specific tier rules
    # cover them now.
    DifficultyRule.where(name: ['Transcended weapons', 'Trans5 weapon present']).delete_all

    updates.each do |name, attrs|
      rule = DifficultyRule.find_by(name: name)
      next unless rule

      params = (rule.params || {}).deep_dup.merge(attrs[:params] || {})
      rule.update!(weight: attrs[:weight], params: params)
    end
  end

  REVERT_KEYS = %w[max_uncap_level max_transcendence_step max_awakening_level].freeze

  def down
    # Best-effort revert: drop the upper bounds and restore old weights.
    revert_updates.each do |name, attrs|
      rule = DifficultyRule.find_by(name: name)
      next unless rule

      params = (rule.params || {}).deep_dup
      REVERT_KEYS.each { |k| params.delete(k) }
      rule.update!(weight: attrs[:weight], params: params)
    end
  end

  private

  def updates
    {
      'Destroyer weapon FLB' => {
        weight: 5.0,
        params: { 'max_uncap_level' => 4 }
      },
      'Destroyer weapon ULB' => {
        # Was 6 alone + 5 from FLB = 11 stacked.
        weight: 11.0,
        params: {}
      },
      'Trans3 Dark Opus weapon' => {
        weight: 3.0,
        params: { 'max_transcendence_step' => 4 }
      },
      'Trans5 Dark Opus weapon' => {
        # Was 4 alone + 3 from Trans3 = 7 stacked.
        weight: 7.0,
        params: {}
      },
      'Celestial weapon FLB' => {
        weight: 3.0,
        params: { 'max_uncap_level' => 4 }
      },
      'Celestial weapon ULB' => {
        # Was 3.5 alone + 3 from FLB = 6.5 stacked; this rule now only fires
        # for ULB weapons WITHOUT awakening 5.
        weight: 6.5,
        params: { 'max_awakening_level' => 4 }
      },
      'Celestial weapon ULB + Awakening 5+' => {
        # Was 4 alone + 3 + 3.5 = 10.5 stacked.
        weight: 10.5,
        params: {}
      },
      'Illustrious weapon' => {
        # User specified equal to Trans5 Dark Opus.
        weight: 7.0,
        params: {}
      }
    }
  end
  # rubocop:enable Metrics/MethodLength

  def revert_updates
    {
      'Destroyer weapon FLB' => { weight: 5.0 },
      'Destroyer weapon ULB' => { weight: 6.0 },
      'Trans3 Dark Opus weapon' => { weight: 3.0 },
      'Trans5 Dark Opus weapon' => { weight: 4.0 },
      'Celestial weapon FLB' => { weight: 3.0 },
      'Celestial weapon ULB' => { weight: 3.5 },
      'Celestial weapon ULB + Awakening 5+' => { weight: 4.0 },
      'Illustrious weapon' => { weight: 4.0 }
    }
  end
end
