class SplitSeasonalCharacterTiers < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  # Mirrors the weapon seasonal tiering on characters:
  #   Formal > Halloween/Valentine/Holiday > Summer/Yukata
  # CharacterSeasonal now supports decay_per_year too, so older seasonals
  # progressively contribute less than recent ones.
  def up
    return unless ActiveRecord::Base.connection.table_exists?(:difficulty_rules)

    DifficultyRule.where(name: ['Seasonal characters', 'Multiple seasonals']).delete_all

    rules.each do |attrs|
      DifficultyRule.find_or_create_by!(name: attrs[:name]) do |r|
        r.assign_attributes(attrs.merge(active: true))
      end
    end
  end

  def down
    DifficultyRule.where(name: rules.map { |r| r[:name] }).delete_all
  end

  private

  def rules
    [
      # Formal: shortest availability window — highest score.
      { name: 'Formal seasonal characters', component: 'character',
        rule_type: 'character_seasonal', weight: 5.0,
        params: { 'seasons' => [2], 'min_count' => 1,
                  'scale_by_count' => true, 'max_count' => 3,
                  'decay_per_year' => 0.1, 'decay_floor' => 0.2 } },

      # Halloween / Valentine / Holiday: mid-tier seasonal windows.
      { name: 'Halloween/Valentine/Holiday seasonal characters', component: 'character',
        rule_type: 'character_seasonal', weight: 3.5,
        params: { 'seasons' => [1, 4, 5], 'min_count' => 1,
                  'scale_by_count' => true, 'max_count' => 4,
                  'decay_per_year' => 0.1, 'decay_floor' => 0.15 } },

      # Summer / Yukata: the longest seasonal window.
      { name: 'Summer/Yukata seasonal characters',          component: 'character',
        rule_type: 'character_seasonal', weight: 2.0,
        params: { 'seasons' => [3], 'min_count' => 1,
                  'scale_by_count' => true, 'max_count' => 4,
                  'decay_per_year' => 0.1, 'decay_floor' => 0.15 } }
    ]
  end
end
