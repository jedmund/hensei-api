class SeedCrewRostersForExistingCrews < ActiveRecord::Migration[8.0]
  ELEMENTS = {
    1 => 'Wind',
    2 => 'Fire',
    3 => 'Water',
    4 => 'Earth',
    5 => 'Dark',
    6 => 'Light'
  }.freeze

  def up
    crews = execute("SELECT id FROM crews")
    crews.each do |row|
      crew_id = row['id']

      captain_id = execute(<<~SQL).first&.dig('user_id')
        SELECT user_id FROM crew_memberships
        WHERE crew_id = '#{crew_id}' AND role = 2 AND retired = false
        LIMIT 1
      SQL
      next unless captain_id

      ELEMENTS.each do |element, name|
        execute(<<~SQL)
          INSERT INTO crew_rosters (id, crew_id, created_by_id, name, element, items, created_at, updated_at)
          VALUES (gen_random_uuid(), '#{crew_id}', '#{captain_id}', '#{name}', #{element}, '[]', NOW(), NOW())
          ON CONFLICT (crew_id, element) DO NOTHING
        SQL
      end
    end
  end

  def down
    execute("DELETE FROM crew_rosters")
  end
end
