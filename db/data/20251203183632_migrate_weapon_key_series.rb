# frozen_string_literal: true

class MigrateWeaponKeySeries < ActiveRecord::Migration[8.0]
  # Mapping from legacy series integer (WeaponKey.series array values) to WeaponSeries slug
  LEGACY_TO_SLUG = {
    1 => 'seraphic',
    2 => 'grand',
    3 => 'dark-opus',
    4 => 'revenant',
    5 => 'primal',
    6 => 'beast',
    7 => 'regalia',
    8 => 'omega',
    9 => 'olden-primal',
    10 => 'hollowsky',
    11 => 'xeno',
    12 => 'rose',
    13 => 'ultima',
    14 => 'bahamut',
    15 => 'epic',
    16 => 'cosmos',
    17 => 'superlative',
    18 => 'vintage',
    19 => 'class-champion',
    20 => 'replica',
    21 => 'relic',
    22 => 'rusted',
    23 => 'sephira',
    24 => 'vyrmament',
    26 => 'astral',
    27 => 'draconic',
    28 => 'eternal-splendor',
    29 => 'ancestral',
    30 => 'new-world-foundation',
    31 => 'ennead',
    32 => 'militis',
    33 => 'malice',
    34 => 'menace',
    35 => 'illustrious',
    36 => 'proven',
    37 => 'revans',
    38 => 'world',
    39 => 'exo',
    40 => 'draconic-providence',
    41 => 'celestial',
    42 => 'omega-rebirth',
    43 => 'collab',
    98 => 'event',
    99 => 'gacha'
  }.freeze

  def up
    # Build lookup from slug to UUID
    slug_to_uuid = WeaponSeries.pluck(:slug, :id).to_h

    puts "Migrating weapon_key series to weapon_key_series join table..."
    key_count = 0

    WeaponKey.find_each do |weapon_key|
      next if weapon_key.series.blank?

      weapon_key.series.each do |legacy_series_id|
        slug = LEGACY_TO_SLUG[legacy_series_id.to_i]
        next unless slug

        weapon_series_id = slug_to_uuid[slug]
        next unless weapon_series_id

        WeaponKeySeries.find_or_create_by!(
          weapon_key_id: weapon_key.id,
          weapon_series_id: weapon_series_id
        )
        key_count += 1
      end
    end

    puts "  Created #{key_count} weapon_key_series associations"
  end

  def down
    WeaponKeySeries.delete_all
  end
end
