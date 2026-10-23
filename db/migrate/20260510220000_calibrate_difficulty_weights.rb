class CalibrateDifficultyWeights < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  # The denominator on each component is the sum of every rule's max possible
  # contribution. Because we've added many tier-specific rules, the denominator
  # ballooned and otherwise endgame grids only fill ~25% of it. This pass
  # rebalances: tier rules carry significantly more weight so they dominate
  # when they fire, and the recency brackets are dialed back since they
  # currently inflate the max without representing real investment.
  def up
    return unless ActiveRecord::Base.connection.table_exists?(:difficulty_rules)

    weight_changes.each do |name, weight|
      DifficultyRule.where(name: name).update_all(weight: weight)
    end

    # update_all bypasses the after_save :bump_ruleset_version callback, so
    # bump explicitly to invalidate already-scored parties under the old weights.
    DifficultyConfig.bump_version! if defined?(DifficultyConfig)
  end

  def down
    revert_changes.each do |name, weight|
      DifficultyRule.where(name: name).update_all(weight: weight)
    end

    DifficultyConfig.bump_version! if defined?(DifficultyConfig)
  end

  private

  def weight_changes
    {
      # Weapon tier ladder — these are the strongest investment signals,
      # so let them swamp the noise from broad rules.
      'Destroyer weapon ULB' => 30.0,
      'Destroyer weapon FLB' => 14.0,
      'Trans5 Dark Opus weapon' => 18.0,
      'Trans3 Dark Opus weapon' => 7.0,
      'Celestial weapon ULB + Awakening 5+' => 28.0,
      'Celestial weapon ULB' => 17.0,
      'Celestial weapon FLB' => 7.0,
      'Illustrious weapon' => 18.0,
      'Superlative weapon' => 6.0,

      # Seasonal/Grand series weapons — meaningful but not as gated as tier.
      'Grand series weapons' => 4.0,
      'Providence/Draconic weapons' => 7.0,
      'Formal seasonal weapons' => 9.0,
      'Halloween/Valentine/Holiday seasonal weapons' => 6.0,
      'Summer/Yukata seasonal weapons' => 4.0,

      # Awakening tier — bump so high awakening on a full grid is noticed.
      'High awakening (level >= 5)' => 2.5,
      'Max awakening (level 10)' => 4.0,

      # Summons.
      'Providence summons' => 8.0,
      'Gacha summon ULB (5★)' => 6.0,
      'Gacha summon FLB (4★)' => 3.0,
      'Gacha summon MLB (3★)' => 2.0,

      # Character investments.
      'Grand characters' => 4.0,
      'Eternal/Evoker characters' => 4.0,
      'Perpetuity ring on any character' => 6.0,
      'Trans5 character present' => 6.0,

      # Recency brackets — dial back so they don't dominate the denominator.
      'Weapon: released < 14d' => 1.5,
      'Weapon: released < 30d' => 1.0,
      'Weapon: released < 90d' => 0.5,
      'Weapon: released < 180d' => 0.25,
      'Character: released < 14d' => 1.5,
      'Character: released < 30d' => 1.0,
      'Character: released < 90d' => 0.5,
      'Character: released < 180d' => 0.25,
      'Summon: released < 14d' => 1.5,
      'Summon: released < 30d' => 1.0,
      'Summon: released < 90d' => 0.5,
      'Summon: released < 180d' => 0.25
    }
  end

  def revert_changes
    {
      'Destroyer weapon ULB' => 11.0,
      'Destroyer weapon FLB' => 5.0,
      'Trans5 Dark Opus weapon' => 7.0,
      'Trans3 Dark Opus weapon' => 3.0,
      'Celestial weapon ULB + Awakening 5+' => 10.5,
      'Celestial weapon ULB' => 6.5,
      'Celestial weapon FLB' => 3.0,
      'Illustrious weapon' => 7.0,
      'Superlative weapon' => 2.5,
      'Grand series weapons' => 2.0,
      'Providence/Draconic weapons' => 3.0,
      'Formal seasonal weapons' => 5.0,
      'Halloween/Valentine/Holiday seasonal weapons' => 3.5,
      'Summer/Yukata seasonal weapons' => 2.0,
      'High awakening (level >= 5)' => 1.0,
      'Max awakening (level 10)' => 1.5,
      'Providence summons' => 3.0,
      'Gacha summon ULB (5★)' => 3.0,
      'Gacha summon FLB (4★)' => 2.0,
      'Gacha summon MLB (3★)' => 1.5,
      'Grand characters' => 2.0,
      'Eternal/Evoker characters' => 2.0,
      'Perpetuity ring on any character' => 3.5,
      'Trans5 character present' => 3.0,
      'Weapon: released < 14d' => 4.0,
      'Weapon: released < 30d' => 3.0,
      'Weapon: released < 90d' => 2.0,
      'Weapon: released < 180d' => 1.0,
      'Character: released < 14d' => 4.0,
      'Character: released < 30d' => 3.0,
      'Character: released < 90d' => 2.0,
      'Character: released < 180d' => 1.0,
      'Summon: released < 14d' => 4.0,
      'Summon: released < 30d' => 3.0,
      'Summon: released < 90d' => 2.0,
      'Summon: released < 180d' => 1.0
    }
  end
  # rubocop:enable Metrics/MethodLength
end
