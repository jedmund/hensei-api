class SeedGachaSunstoneSummonRules < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  # Each uncap on a gacha summon costs a sunstone (3★ MLB and 4★ FLB), which
  # is a very limited resource. Score those tiers explicitly so endgame
  # parties register the investment.
  def up
    return unless ActiveRecord::Base.connection.table_exists?(:difficulty_rules)

    # Constrain the existing ULB rule to uncap 5 only so the new tiers
    # don't overlap, and bump its weight in line with the value of an
    # Ultimate-uncap gacha summon.
    if (ulb = DifficultyRule.find_by(name: 'High uncap on gacha summons'))
      params = (ulb.params || {}).deep_dup
      params['min_uncap_level'] = 5
      params['max_uncap_level'] = 5
      ulb.update!(weight: 3.0, params: params)
      ulb.update!(name: 'Gacha summon ULB (5★)')
    end

    rules.each do |attrs|
      DifficultyRule.find_or_create_by!(name: attrs[:name]) do |r|
        r.assign_attributes(attrs.merge(active: true))
      end
    end
  end

  def down
    DifficultyRule.where(name: ['Gacha summon MLB (3★)', 'Gacha summon FLB (4★)']).delete_all
    if (rule = DifficultyRule.find_by(name: 'Gacha summon ULB (5★)'))
      params = (rule.params || {}).deep_dup
      params.delete('max_uncap_level')
      rule.update!(name: 'High uncap on gacha summons', weight: 1.5, params: params)
    end
  end

  private

  def rules
    [
      { name: 'Gacha summon MLB (3★)',                 component: 'summon',
        rule_type: 'summon_uncap_at_least', weight: 1.5,
        params: {
          'min_uncap_level' => 3, 'max_uncap_level' => 3,
          'gacha_filter' => 'gacha',
          'min_count' => 1, 'scale_by_count' => true, 'max_count' => 5
        } },
      { name: 'Gacha summon FLB (4★)',                 component: 'summon',
        rule_type: 'summon_uncap_at_least', weight: 2.0,
        params: {
          'min_uncap_level' => 4, 'max_uncap_level' => 4,
          'gacha_filter' => 'gacha',
          'min_count' => 1, 'scale_by_count' => true, 'max_count' => 5
        } }
    ]
  end
end
