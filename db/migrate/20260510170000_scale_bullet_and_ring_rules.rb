class ScaleBulletAndRingRules < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  # Enables count scaling on rules where each additional match represents
  # real additional investment: top/high-tier mainhand bullets (one weapon
  # can carry multiple), and perpetuity-ringed characters (a team can have
  # several).
  def up
    return unless ActiveRecord::Base.connection.table_exists?(:difficulty_rules)

    patches.each do |name, extra_params|
      rule = DifficultyRule.find_by(name: name)
      next unless rule

      params = (rule.params || {}).deep_dup
      extra_params.each { |k, v| params[k] = v unless params.key?(k) }
      rule.update!(params: params)
    end
  end

  def down
    # Best-effort revert: remove the scaling keys we added.
    DifficultyRule.where(name: patches.keys).each do |rule|
      params = (rule.params || {}).deep_dup
      params.delete('scale_by_count')
      params.delete('max_count')
      rule.update!(params: params)
    end
  end

  private

  def patches
    {
      'Mainhand: top-tier Expert Model bullet'  => { 'scale_by_count' => true, 'max_count' => 4 },
      'Mainhand: high-tier Expert Model bullet' => { 'scale_by_count' => true, 'max_count' => 4 },
      'Perpetuity ring on any character'        => { 'scale_by_count' => true, 'max_count' => 5 }
    }
  end
end
