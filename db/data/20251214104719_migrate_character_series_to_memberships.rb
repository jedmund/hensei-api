# frozen_string_literal: true

class MigrateCharacterSeriesToMemberships < ActiveRecord::Migration[8.0]
  # Mapping from legacy integer values to slugs
  LEGACY_TO_SLUG = {
    1 => 'standard',
    2 => 'grand',
    3 => 'zodiac',
    4 => 'promo',
    5 => 'collab',
    6 => 'eternal',
    7 => 'evoker',
    8 => 'saint',
    9 => 'fantasy',
    10 => 'summer',
    11 => 'yukata',
    12 => 'valentine',
    13 => 'halloween',
    14 => 'formal',
    15 => 'event'
  }.freeze

  def up
    # Build lookup hash: slug -> UUID
    slug_to_uuid = CharacterSeries.pluck(:slug, :id).to_h

    migrated = 0
    memberships_created = 0

    Character.where.not(series: []).find_each do |character|
      character.series.each do |series_int|
        slug = LEGACY_TO_SLUG[series_int]
        next unless slug

        series_id = slug_to_uuid[slug]
        next unless series_id

        CharacterSeriesMembership.find_or_create_by!(
          character_id: character.id,
          character_series_id: series_id
        )
        memberships_created += 1
      end
      migrated += 1
    end

    puts "Migrated #{migrated} characters, created #{memberships_created} memberships"
  end

  def down
    CharacterSeriesMembership.delete_all
  end
end
