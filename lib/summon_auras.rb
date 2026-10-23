# frozen_string_literal: true

# The summon-aura build: a summon's stored wiki_raw, series and element in; its summon_auras
# rows out, upserted by natural key. See SummonAuras::Build::Runner.
module SummonAuras
  BUILD_MODES = %w[off shadow write].freeze

  # SUMMON_AURA_BUILD: what the deploy build does. "off" (nothing), "shadow" (build, diff,
  # roll back; never fails a deploy) or "write" (stale summons are rebuilt). Read here and
  # nowhere else.
  def self.build_mode
    mode = ENV.fetch("SUMMON_AURA_BUILD", "off").to_s.strip.downcase
    BUILD_MODES.include?(mode) ? mode : "off"
  end
end
