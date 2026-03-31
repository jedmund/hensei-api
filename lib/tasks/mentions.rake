# frozen_string_literal: true

MENTION_ELEMENT_SLUGS = {
  0 => 'null',
  1 => 'wind',
  2 => 'fire',
  3 => 'water',
  4 => 'earth',
  5 => 'dark',
  6 => 'light'
}.freeze

namespace :mentions do
  desc "Backfill entity mention data in party descriptions (proficiency, style_swap, series, season)"
  task backfill: :environment do
    updated = 0
    skipped = 0
    errors = 0

    # Only parties with descriptions containing mentions
    parties = Party.where("description LIKE ?", '%"type":"mention"%')
    total = parties.count
    puts "Found #{total} parties with mentions"

    parties.find_each.with_index do |party, i|
      json = JSON.parse(party.description)
      changed = backfill_mention_node(json)

      if changed
        party.update_column(:description, JSON.generate(json))
        updated += 1
      else
        skipped += 1
      end

      if ((i + 1) % 100).zero?
        puts "  Processed #{i + 1}/#{total} (#{updated} updated, #{skipped} skipped, #{errors} errors)"
      end
    rescue JSON::ParserError
      skipped += 1
    rescue StandardError => e
      errors += 1
      puts "  Error on party #{party.id}: #{e.message}"
    end

    puts "Done. #{updated} updated, #{skipped} skipped, #{errors} errors out of #{total} total."
  end
end

def backfill_mention_node(node)
  return false unless node.is_a?(Hash)

  changed = false

  if node['type'] == 'mention' && node['attrs']&.dig('id')
    changed = backfill_mention_attrs(node['attrs']['id'])
  end

  # Recurse into content array
  if node['content'].is_a?(Array)
    node['content'].each do |child|
      changed = true if backfill_mention_node(child)
    end
  end

  changed
end

def backfill_mention_attrs(attrs)
  entity_type = attrs['type']&.capitalize || attrs['searchableType']
  granblue_id = attrs['granblue_id'] || attrs['granblueId']
  return false unless entity_type && granblue_id

  entity = find_mention_entity(entity_type, granblue_id)
  return false unless entity

  update_mention_for_entity(attrs, entity, entity_type)
end

def find_mention_entity(entity_type, granblue_id)
  case entity_type
  when 'Character'
    Character.includes(:character_series_records).find_by(granblue_id: granblue_id)
  when 'Weapon'
    Weapon.find_by(granblue_id: granblue_id)
  when 'Summon'
    Summon.find_by(granblue_id: granblue_id)
  end
end

def update_mention_for_entity(attrs, entity, entity_type)
  case entity_type
  when 'Character'
    update_character_mention(attrs, entity)
  when 'Weapon'
    update_weapon_mention(attrs, entity)
  when 'Summon'
    ensure_element_format(attrs, entity)
  end
  true
end

def update_character_mention(attrs, entity)
  proficiency = [entity.proficiency1, entity.proficiency2].compact.presence
  attrs['proficiency'] = proficiency if proficiency
  attrs['styleSwap'] = entity.style_swap
  attrs['season'] = entity.season

  series = entity.character_series_records.sort_by(&:order).map do |s|
    { 'id' => s.id, 'slug' => s.slug, 'name' => { 'en' => s.name_en, 'ja' => s.name_jp } }
  end
  attrs['series'] = series if series.any?

  ensure_element_format(attrs, entity)
end

def update_weapon_mention(attrs, entity)
  attrs['proficiency'] = entity.proficiency if entity.proficiency
  ensure_element_format(attrs, entity)
end

def ensure_element_format(attrs, entity)
  return if attrs['element'].is_a?(Hash)

  el = entity.element.to_i
  attrs['element'] = { 'id' => el, 'slug' => MENTION_ELEMENT_SLUGS[el] || 'null' }
end
