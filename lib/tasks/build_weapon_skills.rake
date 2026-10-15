# frozen_string_literal: true

namespace :granblue do
  desc "Build weapon skills from the stored sources and the curation overlay (WeaponSkills::Build). " \
       "mode=shadow (default unless WEAPON_SKILL_BUILD=write) builds in a rolled-back transaction and prints the " \
       "parity diff by series; mode=write keeps the result. Builds only weapons whose fingerprint changed unless " \
       "all=true; ids=GRANBLUE_ID,... and series=SLUG,... narrow the run. Exits nonzero if any weapon failed."
  task build_weapon_skills: :environment do
    ActiveRecord::Base.logger = nil
    mode = ENV["mode"].presence || (WeaponSkills.build_mode == "write" ? "write" : "shadow")
    abort "mode must be shadow or write (got #{mode.inspect})" unless WeaponSkills::Build::Runner::MODES.include?(mode)

    summary = WeaponSkills::Build::Runner.new(
      mode: mode,
      ids: ENV["ids"].to_s.split(",").map(&:strip).compact_blank.presence,
      series: ENV["series"].to_s.split(",").map(&:strip).compact_blank.presence,
      all: ENV["all"] == "true"
    ).call
    exit(1) if summary.failed.positive?
  end
end
