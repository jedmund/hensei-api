# frozen_string_literal: true

module Events
  # Monthly event schedule sync (gbf.wiki + the official monthly post).
  # First pass: a stub. The source fetchers and parsers are wired in later;
  # until then this only logs so the editor trigger can be exercised.
  class ScheduleSyncJob < ApplicationJob
    queue_as :maintenance

    def perform(requested_by_id = nil)
      Rails.logger.info("[Events::ScheduleSyncJob] sync requested#{" by user #{requested_by_id}" if requested_by_id}; " \
                        'source parsers are not wired yet, nothing to do')
      nil
    end
  end
end
