# frozen_string_literal: true

module Sources
  # Refreshes the stored gbf.wiki Module:StatusList (Sources::WikiStatusList): one request, run by
  # sidekiq-scheduler on the 2nd and the 20th (config/sidekiq.yml), so a fresh database fills its
  # list without a manual fetch. When the list changed, every character's fingerprint moved, so
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

    def perform
      result = WikiStatusList.fetch!
      Rails.logger.info "[STATUS_LIST] #{result.changed ? 'updated' : 'unchanged'} (sha256 #{result.source.sha256[0, 12]})"
      CharacterSkills::StaleBuildJob.perform_later if result.changed && CharacterSkills.build_mode != 'off'
      result
    end
  end
end
