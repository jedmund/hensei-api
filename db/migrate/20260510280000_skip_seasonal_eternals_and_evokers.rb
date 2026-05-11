class SkipSeasonalEternalsAndEvokers < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  # Eternals and Evokers each have seasonal variants. When a character is a
  # Summer Eternal we want only the seasonal rule to fire, not the Eternal
  # rule — otherwise that character double-counts and overweights the
  # 'invested in core uncap content' signal. Set single_series_only on the
  # Eternal/Evoker rule so characters with more than one series membership
  # are excluded.
  def up
    return unless ActiveRecord::Base.connection.table_exists?(:difficulty_rules)

    rule = DifficultyRule.find_by(name: 'Eternal/Evoker characters')
    return unless rule

    params = (rule.params || {}).deep_dup
    params['single_series_only'] = true
    rule.update!(params: params)
  end

  def down
    rule = DifficultyRule.find_by(name: 'Eternal/Evoker characters')
    return unless rule

    params = (rule.params || {}).deep_dup
    params.delete('single_series_only')
    rule.update!(params: params)
  end
end
