# frozen_string_literal: true

module CharacterSkills
  # Builds one character's skills after it's created or one of its build inputs changes
  # (Character#enqueue_skill_build). Writes when the character has no skills yet, or when
  # CHARACTER_SKILL_BUILD is write; otherwise builds in shadow and logs what would change,
  # and the deploy build (or an editor's Reparse) writes it later. The runner queues the icon
  # download for any new stems after a write.
  #
  # Never overlaps the stale build or another build of the same character (BuildLock): when one is
  # running, it re-queues itself a minute later.
  class BuildJob < ApplicationJob
    queue_as :default

    discard_on ActiveRecord::RecordNotFound

    RETRY_WAIT = 1.minute

    def perform(character_id)
      summary = nil
      ran = BuildLock.character(character_id) { summary = build(Character.find(character_id)) }
      unless ran
        Rails.logger.info "[CHARACTER_SKILLS] #{character_id}: another build is running; re-queued"
        self.class.set(wait: RETRY_WAIT).perform_later(character_id)
      end
      summary
    end

    def self.mode_for(character)
      return "write" if CharacterSkills.build_mode == "write"

      CharacterSkill.exists?(character_id: character.id) ? "shadow" : "write"
    end

    private

    def build(character)
      mode = self.class.mode_for(character)
      log = StringIO.new
      summary = Build::Runner.new(mode: mode, characters: [character], io: log).call
      Rails.logger.info "[CHARACTER_SKILLS] #{character.granblue_id} (#{mode}): #{log.string.strip.lines.last&.strip}"
      log.string.lines.each { |line| Rails.logger.info "[CHARACTER_SKILLS]   #{line.strip}" } if mode == "shadow"
      summary
    end
  end
end
