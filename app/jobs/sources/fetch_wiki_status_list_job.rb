# frozen_string_literal: true

module Sources
  # Refreshes the stored gbf.wiki Module:StatusList (Sources::WikiStatusList). The next skill build
  # picks up a changed list through the fingerprint.
  class FetchWikiStatusListJob < ApplicationJob
    queue_as :default
    # A page that doesn't validate won't get better by retrying; the stored list stays.
    discard_on Granblue::Parsers::StatusList::Invalid

    def perform
      result = WikiStatusList.fetch!
      Rails.logger.info "[STATUS_LIST] #{result.changed ? 'updated' : 'unchanged'} (sha256 #{result.source.sha256[0, 12]})"
    end
  end
end
