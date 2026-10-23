# frozen_string_literal: true

module SummonAuras
  # Builds one summon's auras after it's created or one of its build inputs changes
  # (Summon#enqueue_aura_build). Writes when the summon has no auras yet, or when
  # SUMMON_AURA_BUILD is write; otherwise builds in shadow and logs what would change, and
  # the deploy build (or an editor's Reparse) writes it later.
  #
  # Needs no lock: the writer upserts against the tier's unique index, so a build that runs
  # alongside another one can't duplicate a tier.
  class BuildJob < ApplicationJob
    queue_as :default

    discard_on ActiveRecord::RecordNotFound

    def perform(summon_id)
      summon = Summon.find(summon_id)
      mode = self.class.mode_for(summon)
      log = StringIO.new
      summary = Build::Runner.new(mode: mode, ids: [summon.granblue_id], io: log).call
      Rails.logger.info "[SUMMON_AURAS] #{summon.granblue_id} (#{mode}): #{log.string.strip.lines.last&.strip}"
      log.string.lines.each { |line| Rails.logger.info "[SUMMON_AURAS]   #{line.strip}" } if mode == "shadow"
      summary
    end

    def self.mode_for(summon)
      return "write" if SummonAuras.build_mode == "write"

      SummonAura.exists?(summon_granblue_id: summon.granblue_id) ? "shadow" : "write"
    end
  end
end
