# frozen_string_literal: true

namespace :granblue do
  ELEMENT_WORD = { 1 => "wind", 2 => "fire", 3 => "water", 4 => "earth", 5 => "dark", 6 => "light" }.freeze
  AURA_KEYS = %w[summon_granblue_id slot target element value uncap_level transcendence_stage condition description_en].freeze

  desc "Extract summon auras from summons.wiki_raw -> data/summon_aura_data.json"
  task extract_summon_aura_data: :environment do
    require Rails.root.join("lib/granblue/extractors/summon_aura_extractor")
    ex = Granblue::Extractors::SummonAuraExtractor.new

    rows = []
    no_aura = []
    Summon.where.not(wiki_raw: [nil, ""]).find_each do |s|
      recs = ex.extract(s.wiki_raw, granblue_id: s.granblue_id,
                        series: s.summon_series&.slug, element: ELEMENT_WORD[s.element])
      recs.empty? ? no_aura << s.name_en : rows.concat(recs)
    end

    rows = rows.map { |r| r.transform_keys(&:to_s) }
               .sort_by { |r| [r["summon_granblue_id"], r["slot"], r["uncap_level"], r["transcendence_stage"]] }
    File.write(Rails.root.join("data", "summon_aura_data.json"), JSON.pretty_generate(rows) + "\n")
    puts "Extracted #{rows.size} aura rows from #{Summon.where.not(wiki_raw: [nil, '']).count - no_aura.size} summons " \
         "(#{no_aura.size} have no passive aura — call-only)."
  end

  desc "Sync summon_auras table from data/summon_aura_data.json (upsert + prune)"
  task load_summon_aura_data: :environment do
    records = JSON.parse(File.read(Rails.root.join("data", "summon_aura_data.json")))
    keys = records.map { |r| r.values_at("summon_granblue_id", "slot", "uncap_level", "transcendence_stage") }.to_set

    records.each do |r|
      a = SummonAura.find_or_initialize_by(
        summon_granblue_id: r["summon_granblue_id"], slot: r["slot"],
        uncap_level: r["uncap_level"], transcendence_stage: r["transcendence_stage"]
      )
      AURA_KEYS.each { |c| a[c] = r[c] }
      a.save!
    end
    pruned = SummonAura.all.reject do |a|
      keys.include?([a.summon_granblue_id, a.slot, a.uncap_level, a.transcendence_stage])
    end
    pruned.each(&:destroy)
    puts "Loaded #{records.size} aura rows; pruned #{pruned.size}; total #{SummonAura.count}."
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
      else unresolved[gs.summon.name_en] += 1 end
    end
    pct = total.zero? ? 0 : (100.0 * resolved / total).round(1)
    puts "equipped aura-slot summons resolving to aura data: #{resolved}/#{total} (#{pct}%)"
    puts "top unresolved (call-only or gaps): #{unresolved.sort_by { |_, c| -c }.first(12).to_h}"
  end
end
