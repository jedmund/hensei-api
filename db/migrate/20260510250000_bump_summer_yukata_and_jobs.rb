class BumpSummerYukataAndJobs < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

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
      # Summer/Yukata seasonals — still the easiest season to roll for, but
      # the prior numbers undersold the investment to obtain a specific unit.
      'Summer/Yukata seasonal weapons' => 6.0,
      'Summer/Yukata seasonal characters' => 4.0,

      # Origin classes are gated behind end-of-game content and a long
      # mastery grind; they're easily the rarest job tier.
      'Origin job' => 10.0,

      # Row V is more accessible but still requires significant progression.
      'Row V job' => 4.0
    }
  end

  def revert_changes
    {
      'Summer/Yukata seasonal weapons' => 4.0,
      'Summer/Yukata seasonal characters' => 2.0,
      'Origin job' => 3.0,
      'Row V job' => 2.0
    }
  end
end
