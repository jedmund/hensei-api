# frozen_string_literal: true

class MigrateWeaponsToWeaponSeries < ActiveRecord::Migration[8.0]
  # Mapping from legacy series integer (Weapon.series column) to WeaponSeries slug
  LEGACY_TO_SLUG = {
    0 => 'seraphic',
    1 => 'grand',
    2 => 'dark-opus',
    4 => 'revenant',
    6 => 'primal',
    5 => 'beast',
    7 => 'beast',
    9 => 'omega',
    8 => 'regalia',
    10 => 'primal',
    12 => 'hollowsky',
    13 => 'xeno',
    15 => 'rose',
    17 => 'ultima',
    16 => 'bahamut',
    18 => 'epic',
    20 => 'cosmos',
    22 => 'superlative',
    23 => 'vintage',
    24 => 'class-champion',
    28 => 'sephira',
    14 => 'astral',
    3 => 'draconic',
    21 => 'ancestral',
    29 => 'new-world-foundation',
    19 => 'ennead',
    11 => 'militis',
    26 => 'malice',
    27 => 'menace',
    31 => 'illustrious',
    25 => 'proven',
    30 => 'revans',
    32 => 'world',
    33 => 'exo',
    34 => 'draconic-providence',
    37 => 'celestial',
    41 => 'celestial',
    38 => 'omega-rebirth',
    43 => 'collab',
    35 => 'event',
    -1 => 'gacha',
    36 => 'gacha'
  }.freeze

  def up
    # Build lookup from slug to UUID
    slug_to_uuid = WeaponSeries.pluck(:slug, :id).to_h

    puts 'Migrating weapons to use weapon_series_id...'
    migrated = 0
    skipped = 0

    Weapon.find_each do |weapon|
      next if weapon.series.blank?

      slug = LEGACY_TO_SLUG[weapon.series.to_i]
      unless slug
        puts "  Warning: No slug mapping for legacy series #{weapon.series} (weapon: #{weapon.name_en})"
        skipped += 1
        next
      end

      weapon_series_id = slug_to_uuid[slug]
      unless weapon_series_id
        puts "  Warning: No weapon_series found for slug '#{slug}' (weapon: #{weapon.name_en})"
        skipped += 1
        next
      end

      weapon.update_column(:weapon_series_id, weapon_series_id)
      migrated += 1
    end

    puts "  Migrated #{migrated} weapons, skipped #{skipped}"
  end

  def down
    Weapon.update_all(weapon_series_id: nil)
  end
end
