# frozen_string_literal: true

namespace :mentions do
  desc "Backfill entity mention data in party descriptions (proficiency, style_swap, series, season)"
  task backfill: :environment do
    ELEMENT_SLUGS = {
      0 => 'null',
      1 => 'wind',
      2 => 'fire',
      3 => 'water',
      4 => 'earth',
      5 => 'dark',
      6 => 'light'
    }.freeze

    updated = 0
    skipped = 0
    errors = 0

    # Only parties with descriptions containing mentions
    parties = Party.where("description LIKE ?", '%"type":"mention"%')
    total = parties.count
    puts "Found #{total} parties with mentions"

    parties.find_each.with_index do |party, i|
      begin
        json = JSON.parse(party.description)
      rescue JSON::ParserError
        skipped += 1
        next
      end

      changed = backfill_node(json)

      if changed
        party.update_column(:description, JSON.generate(json))
        updated += 1
      else
        skipped += 1
      end

      if (i + 1) % 100 == 0
        puts "  Processed #{i + 1}/#{total} (#{updated} updated, #{skipped} skipped, #{errors} errors)"
      end
    rescue => e
      errors += 1
      puts "  Error on party #{party.id}: #{e.message}"
    end

    puts "Done. #{updated} updated, #{skipped} skipped, #{errors} errors out of #{total} total."
  end
end

def backfill_node(node)
  return false unless node.is_a?(Hash)

  changed = false

  if node['type'] == 'mention' && node['attrs']&.dig('id')
    attrs = node['attrs']['id']
    entity_type = attrs['type']&.capitalize || attrs['searchableType']
    granblue_id = attrs['granblue_id'] || attrs['granblueId']

    if entity_type && granblue_id
      entity = case entity_type
               when 'Character'
                 Character.includes(:character_series_records).find_by(granblue_id: granblue_id)
               when 'Weapon'
                 Weapon.find_by(granblue_id: granblue_id)
               when 'Summon'
                 Summon.find_by(granblue_id: granblue_id)
               end

      if entity
        case entity_type
        when 'Character'
          proficiency = [entity.proficiency1, entity.proficiency2].compact.presence
          attrs['proficiency'] = proficiency if proficiency
          attrs['styleSwap'] = entity.style_swap
          attrs['season'] = entity.season

          series = entity.character_series_records.sort_by(&:order).map do |s|
            { 'id' => s.id, 'slug' => s.slug, 'name' => { 'en' => s.name_en, 'ja' => s.name_jp } }
          end
          attrs['series'] = series if series.any?

          # Ensure element is in object format
          unless attrs['element'].is_a?(Hash)
            el = entity.element.to_i
            attrs['element'] = { 'id' => el, 'slug' => ELEMENT_SLUGS[el] || 'null' }
          end

          changed = true
        when 'Weapon'
          attrs['proficiency'] = entity.proficiency if entity.proficiency

          unless attrs['element'].is_a?(Hash)
            el = entity.element.to_i
            attrs['element'] = { 'id' => el, 'slug' => ELEMENT_SLUGS[el] || 'null' }
          end

          changed = true
        when 'Summon'
          unless attrs['element'].is_a?(Hash)
            el = entity.element.to_i
            attrs['element'] = { 'id' => el, 'slug' => ELEMENT_SLUGS[el] || 'null' }
          end

          changed = true
        end
      end
    end
  end

  # Recurse into content array
  if node['content'].is_a?(Array)
    node['content'].each do |child|
      changed = true if backfill_node(child)
    end
  end

  changed
end
