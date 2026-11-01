# frozen_string_literal: true

# Folds gw_events into events: each Guild War becomes an approved
# unite_and_fight event, and crew participations point at events.
#
# A Guild War keeps its id, so URLs and stored references still work. When an
# events row already has the same kind and number, the Guild War isn't copied;
# its participations move to that row instead.
#
# Stored dates are Day 1 and Day 8 in JST. starts_at is Day 1 at 19:00 JST and
# ends_at is Day 8 at 23:59:59 JST. The columns hold UTC without a zone, so the
# times are converted explicitly rather than relying on the session time zone.
#
# Runs in one transaction. Only counts are logged.
class MergeGwEventsIntoEvents < ActiveRecord::Migration[8.1]
  UNITE_AND_FIGHT = 3
  APPROVED = 1

  def up
    kind_before = count("SELECT count(*) FROM events WHERE kind = #{UNITE_AND_FIGHT}")
    gw_total = count('SELECT count(*) FROM gw_events')
    participations = count('SELECT count(*) FROM crew_gw_participations')

    inserted = exec_update(<<~SQL.squish)
      INSERT INTO events (id, name_en, name_jp, kind, element, event_number, starts_at, ends_at,
                          status, series, source_refs, source_payload, created_at, updated_at)
      SELECT g.id, 'Unite and Fight #' || g.event_number, '星の古戦場 #' || g.event_number, #{UNITE_AND_FIGHT}, g.element, g.event_number,
             ((g.start_date + time '19:00:00') AT TIME ZONE 'Asia/Tokyo') AT TIME ZONE 'UTC',
             ((g.end_date + time '23:59:59') AT TIME ZONE 'Asia/Tokyo') AT TIME ZONE 'UTC',
             #{APPROVED}, 'unite_and_fight', '{}'::jsonb, '{}'::jsonb, g.created_at, g.updated_at
      FROM gw_events g
      WHERE NOT EXISTS (
        SELECT 1 FROM events e WHERE e.kind = #{UNITE_AND_FIGHT} AND e.event_number = g.event_number
      )
    SQL
    merged = gw_total - inserted

    # The old foreign key points at gw_events, so it goes before the remap.
    remove_foreign_key :crew_gw_participations, :gw_events, column: :gw_event_id

    remapped = exec_update(<<~SQL.squish)
      UPDATE crew_gw_participations p
      SET gw_event_id = e.id
      FROM gw_events g
      JOIN events e ON e.kind = #{UNITE_AND_FIGHT} AND e.event_number = g.event_number
      WHERE p.gw_event_id = g.id AND e.id <> g.id
    SQL

    orphans = count(<<~SQL.squish)
      SELECT count(*) FROM crew_gw_participations p
      LEFT JOIN events e ON e.id = p.gw_event_id AND e.kind = #{UNITE_AND_FIGHT}
      WHERE e.id IS NULL
    SQL
    kind_after = count("SELECT count(*) FROM events WHERE kind = #{UNITE_AND_FIGHT}")

    raise "#{orphans} participations don't resolve to a Unite and Fight event" if orphans.positive?
    raise "expected #{kind_before + inserted} Unite and Fight events, found #{kind_after}" if kind_after != kind_before + inserted

    # Raw SQL so Rails doesn't rename the indexes behind our back; they're renamed explicitly.
    execute 'ALTER TABLE crew_gw_participations RENAME COLUMN gw_event_id TO event_id'
    rename_index :crew_gw_participations, 'index_crew_gw_participations_on_crew_id_and_gw_event_id',
                 'index_crew_gw_participations_on_crew_id_and_event_id'
    rename_index :crew_gw_participations, 'index_crew_gw_participations_on_gw_event_id',
                 'index_crew_gw_participations_on_event_id'
    add_foreign_key :crew_gw_participations, :events, column: :event_id

    drop_table :gw_events

    say "gw_events: #{gw_total}; inserted #{inserted}, merged #{merged}; " \
        "participations: #{participations}, remapped #{remapped}; " \
        "unite_and_fight events #{kind_before} -> #{kind_after}"
  end

  # Rebuilds gw_events from every numbered Unite and Fight event (same ids,
  # dates back in JST) and points participations at it again. The events rows
  # stay, so running up afterwards merges into them and changes nothing.
  def down
    create_table :gw_events, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.integer :element, null: false
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.integer :event_number, null: false
      t.timestamps
    end
    add_index :gw_events, :event_number, unique: true
    add_index :gw_events, :start_date

    execute(<<~SQL.squish)
      INSERT INTO gw_events (id, element, start_date, end_date, event_number, created_at, updated_at)
      SELECT id, element,
             ((starts_at AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Tokyo')::date,
             ((ends_at AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Tokyo')::date,
             event_number, created_at, updated_at
      FROM events
      WHERE kind = #{UNITE_AND_FIGHT} AND event_number IS NOT NULL AND element IS NOT NULL
    SQL

    remove_foreign_key :crew_gw_participations, :events, column: :event_id
    rename_index :crew_gw_participations, 'index_crew_gw_participations_on_event_id',
                 'index_crew_gw_participations_on_gw_event_id'
    rename_index :crew_gw_participations, 'index_crew_gw_participations_on_crew_id_and_event_id',
                 'index_crew_gw_participations_on_crew_id_and_gw_event_id'
    execute 'ALTER TABLE crew_gw_participations RENAME COLUMN event_id TO gw_event_id'
    add_foreign_key :crew_gw_participations, :gw_events, column: :gw_event_id
  end

  private

  def count(sql)
    select_value(sql).to_i
  end
end
