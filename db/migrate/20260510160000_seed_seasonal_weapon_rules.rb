class SeedSeasonalWeaponRules < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  # Seeds rules for seasonal weapons (Formal / Halloween / Valentine / Holiday /
  # Summer-Yukata) tiered by availability window, and adds age-decay to both
  # the seasonal rules and the existing Grand-series rule so the score reflects
  # how recently a hard-to-obtain weapon was released.
  #
  # Decay model: contribution per match = weight × max(decay_floor, 1 - decay_per_year × years_since_release).
  # 10% per year with a 10% floor: a freshly-released item contributes its full
  # weight, drops to 90% after a year, and bottoms out at 10% after 9 years.
  def up
    return unless ActiveRecord::Base.connection.table_exists?(:difficulty_rules)

    seasonal_rules.each do |attrs|
      DifficultyRule.find_or_create_by!(name: attrs[:name]) do |r|
        r.assign_attributes(attrs.merge(active: true))
      end
    end

    # Patch the existing Grand-series weapon rule to apply decay so newer
    # Grands score higher than ancient ones.
    grand_rule = DifficultyRule.find_by(name: 'Grand series weapons')
    if grand_rule
      params = grand_rule.params || {}
      params['decay_per_year'] = 0.1 unless params.key?('decay_per_year')
      params['decay_floor'] = 0.2 unless params.key?('decay_floor')
      grand_rule.update!(params: params)
    end
  end

  def down
    DifficultyRule.where(name: seasonal_rules.map { |r| r[:name] }).delete_all
  end

  private

  def seasonal_rules
    [
      # Formal: ~2-week availability per year, the rarest seasonal.
      { name: 'Formal seasonal weapons', component: 'weapon',
        rule_type: 'weapon_seasonal_match', weight: 5.0,
        params: { 'seasons' => [2], 'min_count' => 1,
                  'scale_by_count' => true, 'max_count' => 3,
                  'decay_per_year' => 0.1, 'decay_floor' => 0.2 } },

      # Halloween / Valentine / Holiday: similar mid-tier seasonal windows.
      { name: 'Halloween/Valentine/Holiday seasonal weapons', component: 'weapon',
        rule_type: 'weapon_seasonal_match', weight: 3.5,
        params: { 'seasons' => [1, 4, 5], 'min_count' => 1,
                  'scale_by_count' => true, 'max_count' => 4,
                  'decay_per_year' => 0.1, 'decay_floor' => 0.15 } },

      # Summer / Yukata: longest seasonal window — easier to obtain than the
      # others but still above normal. Roughly on par with Grand series.
      { name: 'Summer/Yukata seasonal weapons',          component: 'weapon',
        rule_type: 'weapon_seasonal_match', weight: 2.0,
        params: { 'seasons' => [3], 'min_count' => 1,
                  'scale_by_count' => true, 'max_count' => 4,
                  'decay_per_year' => 0.1, 'decay_floor' => 0.15 } }
    ]
  end
end
