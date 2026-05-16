class FixJobRowSeeds < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  # The seeded job rules referenced 'V' / 'Origin' / 'IV' but jobs.row is
  # stored as '5' / 'o1' / '4' (plus 'ex1', 'ex2' for extras). Patch the
  # existing rule rows so they actually fire.
  def up
    return unless ActiveRecord::Base.connection.table_exists?(:difficulty_rules)

    patches.each do |name, new_rows|
      rule = DifficultyRule.find_by(name: name)
      next unless rule

      params = (rule.params || {}).deep_dup
      params['rows'] = new_rows
      rule.update!(params: params)
    end
  end

  def down
    revert.each do |name, old_rows|
      rule = DifficultyRule.find_by(name: name)
      next unless rule

      params = (rule.params || {}).deep_dup
      params['rows'] = old_rows
      rule.update!(params: params)
    end
  end

  private

  def patches
    {
      'Row V job' => ['5'],
      'Origin job' => ['o1'],
      'Row IV with Ultimate Mastery' => ['4']
    }
  end

  def revert
    {
      'Row V job' => ['V'],
      'Origin job' => ['Origin'],
      'Row IV with Ultimate Mastery' => ['IV']
    }
  end
end
