# frozen_string_literal: true

# Renumbers element, proficiency and race to the game's own numbers, so imports, image
# names and the game's payloads stop needing a conversion table.
#
#   element      old: 1 Wind  2 Fire  3 Water 4 Earth 5 Dark  6 Light
#                new: 1 Fire  2 Water 3 Earth 4 Wind  5 Light 6 Dark      (0 Null unchanged)
#   proficiency  old: 3 Axe   4 Spear 5 Bow   6 Staff 8 Harp  9 Gun
#                new: 3 Spear 4 Axe   5 Staff 6 Gun   8 Bow   9 Harp      (1, 2, 7, 10, 0 unchanged)
#   race         old: 0 Unknown 5 Primal 6 None
#                new: 5 Other   6 Primal 5 Other                           (1-4, 7-10 unchanged)
#
# Support summon sections follow the element numbers, and Misc moves from 7 to the game's 0.
# A race2 of 0, or a race2 equal to race1 after the move, is cleared: neither is a second race.
#
# Covers the integer columns, the race lists in weapon_skill_effects.condition, the element
# keys of weapons.element_variant_ids, Solomonis proficiency targets (race targets were
# already the game's), and the element/proficiency inside rich-text mention tokens. The maps
# are written out here, not read from GranblueEnums, so this stays correct if those change.
# Runs in one transaction. Raw SQL skips callbacks and leaves updated_at alone; only the
# per-column counts are logged, never row contents.
class RenumberEnumsToGameIds < ActiveRecord::Migration[8.1]
  ELEMENT = { 1 => 4, 2 => 1, 3 => 2, 4 => 3, 5 => 6, 6 => 5 }.freeze
  PROFICIENCY = { 3 => 4, 4 => 3, 5 => 8, 6 => 5, 8 => 9, 9 => 6 }.freeze
  RACE = { 0 => 5, 5 => 6, 6 => 5 }.freeze
  SECTION = ELEMENT.merge(7 => 0).freeze

  ELEMENT_COLUMNS = {
    'characters' => %w[element],
    'collection_artifacts' => %w[element],
    'collection_weapons' => %w[element],
    'events' => %w[element],
    'grid_artifacts' => %w[element],
    'grid_weapons' => %w[element],
    'gw_events' => %w[element],
    'parties' => %w[element],
    'pg_search_documents' => %w[element],
    'raids' => %w[element],
    'summons' => %w[element],
    'weapons' => %w[element]
  }.freeze

  PROFICIENCY_COLUMNS = {
    'artifacts' => %w[proficiency],
    'characters' => %w[proficiency1 proficiency2],
    'collection_artifacts' => %w[proficiency],
    'grid_artifacts' => %w[proficiency],
    'jobs' => %w[proficiency1 proficiency2],
    'weapons' => %w[proficiency]
  }.freeze

  DESCRIPTION_TABLES = %w[parties grid_characters grid_weapons grid_summons].freeze

  def up
    renumber(ELEMENT, PROFICIENCY, RACE, SECTION)
  end

  # Inverse maps. Lossy for race: None and Unknown both became Other, which comes back as
  # Unknown, and cleared race2 values stay cleared.
  def down
    renumber(ELEMENT.invert, PROFICIENCY.invert, { 5 => 0, 6 => 5 }, SECTION.invert)
  end

  private

  def renumber(element, proficiency, race, section)
    ELEMENT_COLUMNS.each { |table, columns| columns.each { |column| remap_column(table, column, element) } }
    PROFICIENCY_COLUMNS.each { |table, columns| columns.each { |column| remap_column(table, column, proficiency) } }

    # Both have a unique index that includes the column, so a single CASE update can collide
    # mid-statement while swapping two values.
    remap_column('crew_rosters', 'element', element, unique: true)
    remap_column('support_summons', 'section', section, unique: true)

    remap_races(race)
    remap_condition_races(race)
    remap_element_variant_ids(element)
    remap_solomonis_targets(proficiency)
    remap_mentions(element, proficiency)
  end

  def remap_column(table, column, map, unique: false)
    # schema.rb lists tables that some databases never created (events, in production).
    unless connection.table_exists?(table)
      say "#{table}.#{column}: skipped, no such table"
      return
    end

    col = connection.quote_column_name(column)
    tbl = connection.quote_table_name(table)
    keys = map.keys.join(', ')

    if unique
      # Move the affected rows out of the way first, then map from the offset values.
      connection.execute("UPDATE #{tbl} SET #{col} = #{col} + 1000 WHERE #{col} IN (#{keys})")
      cases = map.map { |from, to| "WHEN #{from + 1000} THEN #{to}" }.join(' ')
      count = connection.update("UPDATE #{tbl} SET #{col} = CASE #{col} #{cases} END WHERE #{col} >= 1000")
    else
      cases = map.map { |from, to| "WHEN #{from} THEN #{to}" }.join(' ')
      count = connection.update("UPDATE #{tbl} SET #{col} = CASE #{col} #{cases} END WHERE #{col} IN (#{keys})")
    end

    say "#{table}.#{column}: #{count} rows"
  end

  def remap_races(map)
    remap_column('characters', 'race1', map)
    cleared = connection.update('UPDATE characters SET race2 = NULL WHERE race2 = 0') if map.key?(0)
    remap_column('characters', 'race2', map)
    cleared = cleared.to_i + connection.update('UPDATE characters SET race2 = NULL WHERE race2 = race1')
    say "characters.race2: cleared #{cleared} that were 0 or equal to race1"
  end

  def remap_condition_races(map)
    count = 0
    connection.select_rows("SELECT id, condition FROM weapon_skill_effects WHERE condition ? 'races'").each do |id, raw|
      condition = JSON.parse(raw)
      races = Array(condition['races']).map { |r| map.fetch(r.to_i, r.to_i) }.uniq
      next if races == condition['races']

      condition['races'] = races
      update_text(:weapon_skill_effects, :condition, id, condition.to_json)
      count += 1
    end
    say "weapon_skill_effects.condition races: #{count} rows"
  end

  def remap_element_variant_ids(map)
    count = 0
    connection.select_rows('SELECT id, element_variant_ids FROM weapons WHERE element_variant_ids IS NOT NULL').each do |id, raw|
      ids = JSON.parse(raw)
      remapped = ids.to_h { |key, value| [map.fetch(key.to_i, key.to_i).to_s, value] }
      next if remapped == ids

      update_text(:weapons, :element_variant_ids, id, remapped.to_json)
      count += 1
    end
    say "weapons.element_variant_ids: #{count} rows"
  end

  def remap_solomonis_targets(map)
    cases = map.map { |from, to| "WHEN #{from} THEN #{to}" }.join(' ')
    count = connection.update(<<~SQL)
      UPDATE solomonis_guide_effects
      SET target_values = ARRAY(SELECT CASE v #{cases} ELSE v END FROM unnest(target_values) WITH ORDINALITY AS t(v, i) ORDER BY i)
      WHERE target_type = 'proficiency'
    SQL
    say "solomonis_guide_effects proficiency targets: #{count} rows"
  end

  # Mention tokens carry element: { id, weaknessId, slug } and proficiency (an integer, or
  # [proficiency1, proficiency2] for characters).
  def remap_mentions(element, proficiency)
    DESCRIPTION_TABLES.each do |table|
      count = 0
      connection.select_rows("SELECT id, description FROM #{table} WHERE description::text LIKE '%mention%'").each do |id, raw|
        doc = JSON.parse(raw)
        next unless remap_mention_node(doc, element, proficiency)

        update_text(table, :description, id, JSON.generate(doc))
        count += 1
      rescue JSON::ParserError
        next
      end
      say "#{table}.description mentions: #{count} rows"
    end
  end

  # Writes a text or jsonb column from its serialized text.
  def update_text(table, column, id, text)
    connection.update("UPDATE #{table} SET #{column} = #{connection.quote(text)} WHERE id = #{connection.quote(id)}")
  end

  def remap_mention_node(node, element, proficiency)
    case node
    when Array
      node.map { |child| remap_mention_node(child, element, proficiency) }.any?
    when Hash
      changed = false
      attrs = node.dig('attrs', 'id') if node['type'] == 'mention'
      changed = remap_mention_attrs(attrs, element, proficiency) if attrs.is_a?(Hash)
      node.each_value { |child| changed = true if child.is_a?(Enumerable) && remap_mention_node(child, element, proficiency) }
      changed
    else
      false
    end
  end

  def remap_mention_attrs(attrs, element, proficiency)
    changed = false
    if (el = attrs['element']).is_a?(Hash)
      %w[id weaknessId].each do |key|
        next unless el[key].is_a?(Integer) && element.key?(el[key])

        el[key] = element[el[key]]
        changed = true
      end
    end

    case (prof = attrs['proficiency'])
    when Integer
      if proficiency.key?(prof)
        attrs['proficiency'] = proficiency[prof]
        changed = true
      end
    when Array
      remapped = prof.map { |p| p.is_a?(Integer) ? proficiency.fetch(p, p) : p }
      if remapped != prof
        attrs['proficiency'] = remapped
        changed = true
      end
    end
    changed
  end
end
