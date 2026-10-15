# frozen_string_literal: true

# The weapon-skill data pipeline: stored sources → deterministic build → committed
# curation overlay. See docs/weapon-skill-pipeline/README.md.
module WeaponSkills
  BUILD_MODES = %w[off shadow write].freeze

  # WEAPON_SKILL_BUILD: "off" (old writers only), "shadow" (build, diff, roll back) or
  # "write" (the build owns generated rows). Read here and nowhere else.
  def self.build_mode
    mode = ENV.fetch("WEAPON_SKILL_BUILD", "off").to_s.strip.downcase
    BUILD_MODES.include?(mode) ? mode : "off"
  end
end
