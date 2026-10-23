# frozen_string_literal: true

namespace :granblue do
  desc "Build summon auras from the stored sources (SummonAuras::Build::Runner). " \
       "mode=shadow (default unless SUMMON_AURA_BUILD=write) builds in a rolled-back transaction and prints " \
       "the differences; mode=write keeps the result. Builds only summons whose fingerprint changed unless " \
       "all=true; ids=GRANBLUE_ID,... narrows the run; limit=N caps the printed differences. " \
       "Exits nonzero if any summon failed."
  task build_summon_auras: :environment do
    ActiveRecord::Base.logger = nil
    mode = ENV["mode"].presence || (SummonAuras.build_mode == "write" ? "write" : "shadow")
    abort "mode must be shadow or write (got #{mode.inspect})" unless SummonAuras::Build::Runner::MODES.include?(mode)

    summary = SummonAuras::Build::Runner.new(
      mode: mode,
      ids: ENV["ids"].to_s.split(",").map(&:strip).compact_blank.presence,
      all: ENV["all"] == "true",
      diff_limit: ENV["limit"].presence&.to_i
    ).call
    exit(1) if summary.failed.positive?
  end

  desc "Drift check: build every summon in shadow mode and exit nonzero if any summon's built auras differ " \
       "from the stored ones (or a build failed or came out empty). limit=N caps the printed differences."
  task summon_aura_drift: :environment do
    ActiveRecord::Base.logger = nil
    summary = SummonAuras::Build::Runner.new(mode: "shadow", all: true, diff_limit: (ENV["limit"] || 50).to_i).call
    exit(1) if summary.drift?
  end

  desc "Retired: use granblue:build_summon_auras (mode=write, all=true to rebuild everything)."
  task extract_summon_aura_data: :environment do
    abort "granblue:extract_summon_aura_data is retired: auras are built from the stored sources, with no JSON " \
          "snapshot. Use: rake granblue:build_summon_auras mode=write (all=true to rebuild everything)."
  end

  desc "Retired: use granblue:build_summon_auras (mode=write, all=true to rebuild everything)."
  task load_summon_aura_data: :environment do
    abort "granblue:load_summon_aura_data is retired: auras are built from the stored sources, with no JSON " \
          "snapshot. Use: rake granblue:build_summon_auras mode=write (all=true to rebuild everything)."
  end

  desc "Summon-aura coverage: target breakdown + how many real grid summons (main/friend/subaura) resolve to an aura"
  task summon_aura_coverage: :environment do
    puts "auras by target: #{SummonAura.group(:target).count.sort_by { |_, c| -c }.to_h}"
    with = SummonAura.distinct.count(:summon_granblue_id)
    puts "summons with >=1 aura: #{with} / #{Summon.count}"

    # real equipped main/friend/subaura summons — do they resolve to aura data?
    aura_ids = SummonAura.distinct.pluck(:summon_granblue_id).to_set
    scope = GridSummon.where("main = true OR friend = true OR position IN (4,5)").includes(:summon)
    total = 0
    resolved = 0
    unresolved = Hash.new(0)
    scope.find_each do |gs|
      next unless gs.summon
      total += 1
      if aura_ids.include?(gs.summon.granblue_id) then resolved += 1
      else
        unresolved[gs.summon.name_en] += 1
      end
    end
    pct = total.zero? ? 0 : (100.0 * resolved / total).round(1)
    puts "equipped aura-slot summons resolving to aura data: #{resolved}/#{total} (#{pct}%)"
    puts "top unresolved (call-only or gaps): #{unresolved.sort_by { |_, c| -c }.first(12).to_h}"
  end
end
