# frozen_string_literal: true

module CharacterSkills
  # The deploy build outside a deploy: rebuilds the stale characters in CHARACTER_SKILL_BUILD's
  # mode (Build::Runner.deploy: off does nothing, shadow logs a summary, write writes). Queued when
  # a shared build input changes between deploys, such as the stored status list.
  class StaleBuildJob < ApplicationJob
    queue_as :maintenance

    def perform
      log = StringIO.new
      summary = Build::Runner.deploy(io: log)
      log.string.lines.each { |line| Rails.logger.info "[CHARACTER_SKILLS] #{line.strip}" }
      summary
    end
  end
end
