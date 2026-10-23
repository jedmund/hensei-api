# frozen_string_literal: true

module CharacterSkills
  # The deploy build outside a deploy: rebuilds the stale characters in CHARACTER_SKILL_BUILD's
  # mode (Build::Runner.deploy: off does nothing, shadow logs a summary, write writes). Queued when
  # a shared build input changes between deploys, such as the stored status list or icon snapshot.
  #
  # Never overlaps another build (BuildLock): when one is running, it re-queues itself a few
  # minutes later. Back to back is harmless, since the second finds nothing stale.
  class StaleBuildJob < ApplicationJob
    queue_as :maintenance

    RETRY_WAIT = 5.minutes

    def perform
      summary = nil
      ran = BuildLock.all do
        log = StringIO.new
        summary = Build::Runner.deploy(io: log)
        log.string.lines.each { |line| Rails.logger.info "[CHARACTER_SKILLS] #{line.strip}" }
      end
      unless ran
        Rails.logger.info '[CHARACTER_SKILLS] another build is running; stale build re-queued'
        self.class.set(wait: RETRY_WAIT).perform_later
      end
      summary
    end
  end
end
