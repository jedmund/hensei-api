# frozen_string_literal: true

module CharacterSkills
  # Builds one character's skills after it's created or one of its build inputs changes
  # (Character#enqueue_skill_build). Writes when the character has no skills yet, or when
  # CHARACTER_SKILL_BUILD is write; otherwise builds in shadow and logs what would change,
  # and the deploy build (or an editor's Reparse) writes it later. The runner queues the icon
  # download for any new stems after a write.
  class BuildJob < ApplicationJob
    queue_as :default

    discard_on ActiveRecord::RecordNotFound

    def perform(character_id)
      character = Character.find(character_id)
      mode = self.class.mode_for(character)
      log = StringIO.new
      summary = Build::Runner.new(mode: mode, characters: [character], io: log).call
      Rails.logger.info "[CHARACTER_SKILLS] #{character.granblue_id} (#{mode}): #{log.string.strip.lines.last&.strip}"
      log.string.lines.each { |line| Rails.logger.info "[CHARACTER_SKILLS]   #{line.strip}" } if mode == "shadow"
      summary
    end

    def self.mode_for(character)
      return "write" if CharacterSkills.build_mode == "write"

      CharacterSkill.exists?(character_id: character.id) ? "shadow" : "write"
    end
  end
end
