# frozen_string_literal: true

module Sources
  # Refreshes the stored gbf.wiki Module:StatusList (Sources::WikiStatusList): one request. Queued
  # after a new character release (after_release, from GachaSimulation::BannerImport), so the list
  # picks up the release's new statuses once the wiki has them; bin/rails
  # granblue:fetch_wiki_status_list runs it by hand. When the list changed, every character's fingerprint moved, so
  # the stale build is queued (CharacterSkills::StaleBuildJob, in CHARACTER_SKILL_BUILD's mode;
  # nothing when it's off). An unchanged list queues nothing.
  #
  # Failures keep the stored list: a page that doesn't validate is dropped at once, and anything
  # else (the wiki down, a challenge page, a timeout) is retried twice an hour apart, then dropped
  # until the next scheduled run.
  class FetchWikiStatusListJob < ApplicationJob
    queue_as :maintenance

    retry_on StandardError, wait: 1.hour, attempts: 3 do |_job, error|
      Rails.logger.warn "[STATUS_LIST] fetch failed, keeping the stored list: #{error.class}: #{error.message}"
    end
    discard_on Granblue::Parsers::StatusList::Invalid do |_job, error|
      Rails.logger.warn "[STATUS_LIST] rejected an invalid list, keeping the stored one: #{error.message}"
    end

    # New characters release on banners that start at 12:00 JST; the regular rollovers start at
    # 19:00. The wiki fills in a release's statuses over the following days.
    RELEASE_HOUR = 12
    AFTER_RELEASE = [12.hours, 3.days].freeze

    # Queues the refreshes for a banner seen for the first time, when it is a character release.
    # Returns the run times queued (none for any other banner).
    def self.after_release(starts_at)
      tokyo = starts_at.in_time_zone('Asia/Tokyo')
      return [] unless tokyo.hour == RELEASE_HOUR && tokyo.min.zero?

      AFTER_RELEASE.map { |delay| starts_at + delay }.select(&:future?).each { |at| set(wait_until: at).perform_later }
    end

    def perform
      result = WikiStatusList.fetch!
      Rails.logger.info "[STATUS_LIST] #{result.changed ? 'updated' : 'unchanged'} (sha256 #{result.source.sha256[0, 12]})"
      CharacterSkills::StaleBuildJob.perform_later if result.changed && CharacterSkills.build_mode != 'off'
      result
    end
  end
end
