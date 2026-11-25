# frozen_string_literal: true

# Dread Barrage's NM215, a new difficulty that opens on the event's fourth
# day (Event::RAID_UNLOCK_DAYS). Named like the other Dread Barrage raids,
# and linked after NM175 to running and upcoming Dread Barrages that have it;
# linking fills in its unlock day. A raid that already exists is left alone,
# so editors' changes win.
class AddDreadBarrageNm215 < ActiveRecord::Migration[8.1]
  SLUG = 'db215'
  AFTER = 'db175'

  def up
    group = RaidGroup.find_by(name_en: 'Dread Barrage')
    return say('No Dread Barrage group; skipped') unless group

    raid = Raid.find_or_create_by!(slug: SLUG) do |r|
      r.group = group
      r.name_en = 'NM215'
      r.name_jp = '215HELL'
      r.level = 215
      r.element = 0
      r.player_count = 30
    end

    linked = Event.dread_barrage.where(ends_at: Time.current..).includes(event_raids: :raid).count do |event|
      linked_after?(event, raid)
    end
    say "NM215 linked to #{linked} Dread Barrage events"
  end

  def down
    # Nothing to undo: teams may already point at this raid.
  end

  private

  # Links `raid` right after NM175; false when the event lacks NM175 or
  # already has the raid
  def linked_after?(event, raid)
    slugs = event.event_raids.map { |row| row.raid.slug }
    return false if slugs.exclude?(AFTER) || slugs.include?(SLUG)

    ids = event.event_raids.flat_map { |row| row.raid.slug == AFTER ? [row.raid_id, raid.id] : [row.raid_id] }
    event.assign_raid_ids(ids) || raise("#{event.name_en}: #{event.errors.full_messages.to_sentence}")
    true
  end
end
