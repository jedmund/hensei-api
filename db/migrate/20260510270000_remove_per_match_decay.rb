class RemovePerMatchDecay < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  # Previously every match contributed weight × per-item decay factor, which
  # made later (older) matches score noticeably less than the first. That
  # surprised editors looking at the breakdown — they expect every Grand
  # weapon / Providence summon / seasonal character to count the same.
  # Strip decay_per_year / decay_floor from every rule that still has them;
  # the helper itself stays around if we want to opt-in to decay later.
  def up
    return unless ActiveRecord::Base.connection.table_exists?(:difficulty_rules)

    DifficultyRule.where("params ? 'decay_per_year' OR params ? 'decay_floor'").find_each do |rule|
      params = (rule.params || {}).deep_dup
      saved_decay = params.delete('decay_per_year')
      saved_floor = params.delete('decay_floor')
      rule.update!(params: params) if saved_decay || saved_floor
    end
  end

  def down
    # No-op: the previous values weren't uniform, and re-seeding would clobber
    # any tuning editors did in the meantime.
  end
end
