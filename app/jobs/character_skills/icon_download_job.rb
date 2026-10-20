# frozen_string_literal: true

module CharacterSkills
  # Downloads ability icons for the stems a build created or changed (queued by
  # CharacterSkills::Build::Runner after a write). Icons already in storage are skipped by the
  # downloader. It's the game CDN, not a wiki, so 0.2s between downloads is enough.
  # rake granblue:download_ability_icons stays the manual bulk path.
  class IconDownloadJob < ApplicationJob
    queue_as :downloads

    THROTTLE = 0.2

    def perform(stems, storage: "s3")
      counts = Hash.new(0)
      Array(stems).uniq.each do |stem|
        result = Granblue::Downloaders::AbilityIconDownloader.new(stem, storage: storage.to_sym, logger: Rails.logger).download
        if result[:skipped]
          counts[:skipped] += 1
        elsif result[:success]
          counts[:downloaded] += 1
          throttle
        else
          counts[:failed] += 1
          Rails.logger.warn "[CHARACTER_SKILL_ICONS] #{stem}: #{result[:error] || 'not downloaded'}"
        end
      end
      Rails.logger.info "[CHARACTER_SKILL_ICONS] #{counts.to_h}"
      counts.to_h
    end

    private

    def throttle = sleep(THROTTLE)
  end
end
