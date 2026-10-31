# frozen_string_literal: true

module PartyViews
  ##
  # Copies the unique-viewer counts buffered in Redis (see Recorder) into
  # party_view_days. Runs every few minutes. It writes each day's running
  # total rather than an increment, so reruns are harmless; yesterday is
  # flushed too so views from just before midnight (UTC) aren't lost. A count
  # never goes down, in case Redis lost a day's sets.
  class FlushJob < ApplicationJob
    queue_as :maintenance

    BATCH_SIZE = 1000

    def perform(now: Time.current)
      today = now.utc.to_date
      [today - 1, today].each { |date| flush(date, now) }
    end

    private

    def flush(date, now)
      counts = Recorder.counts(date)
      # Parties deleted since they were viewed would fail the foreign key.
      existing = counts.keys.each_slice(BATCH_SIZE).flat_map { |ids| Party.where(id: ids).pluck(:id) }

      rows = existing.filter_map do |party_id|
        views = counts[party_id]
        { party_id: party_id, date: date, views: views, created_at: now, updated_at: now } if views.positive?
      end

      rows.each_slice(BATCH_SIZE) do |batch|
        PartyViewDay.upsert_all(
          batch,
          unique_by: %i[party_id date],
          on_duplicate: Arel.sql(
            'views = GREATEST(party_view_days.views, EXCLUDED.views), updated_at = EXCLUDED.updated_at'
          )
        )
      end
    end
  end
end
