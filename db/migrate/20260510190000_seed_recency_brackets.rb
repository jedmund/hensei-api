class SeedRecencyBrackets < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  # Replaces the single "released within 180 days" rules with four mutually
  # exclusive brackets per component (weapon / character / summon). Brand-new
  # items signal active spending; older items get progressively less weight,
  # and anything past 180 days isn't scored.
  def up
    return unless ActiveRecord::Base.connection.table_exists?(:difficulty_rules)

    DifficultyRule.where(name: legacy_names).delete_all

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

  def legacy_names
    [
      'Recently released weapon (180d)',
      'Recently released character (180d)'
    ]
  end

  BRACKETS = [
    { suffix: 'released < 14d',  min_days: 0,   max_days: 14,  weight: 4.0 },
    { suffix: 'released < 30d',  min_days: 14,  max_days: 30,  weight: 3.0 },
    { suffix: 'released < 90d',  min_days: 30,  max_days: 90,  weight: 2.0 },
    { suffix: 'released < 180d', min_days: 90,  max_days: 180, weight: 1.0 }
  ].freeze

  COMPONENTS = {
    'weapon'    => 'weapon_release_within_days',
    'character' => 'character_release_within_days',
    'summon'    => 'summon_release_within_days'
  }.freeze

  def rules
    COMPONENTS.flat_map do |component, rule_type|
      BRACKETS.map do |bracket|
        {
          name: "#{component.capitalize}: #{bracket[:suffix]}",
          component: component,
          rule_type: rule_type,
          weight: bracket[:weight],
          params: {
            'days' => bracket[:max_days],
            'min_days_ago' => bracket[:min_days],
            'min_count' => 1,
            'scale_by_count' => true,
            'max_count' => 3
          }
        }
      end
    end
  end
end
