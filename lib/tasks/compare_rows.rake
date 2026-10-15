# frozen_string_literal: true

namespace :granblue do
  desc "Compare the row compiler (WeaponSkills::Build::Rows) with today's generated version-linked rows. " \
       "ids=GRANBLUE_ID,... and series=SLUG,... narrow the run; notes=store compiles Gameplay Notes from the " \
       "stored expanded sources. Writes data/weapon_skill_parity/compare_rows_last.json for a full run and fails " \
       "on unclassified differences."
  task compare_rows: :environment do
    ActiveRecord::Base.logger = nil
    ids = ENV["ids"].to_s.split(",").map(&:strip).presence
    series = ENV["series"].to_s.split(",").map(&:strip).presence
    notes_source = nil
    if ENV["notes"] == "store"
      store = WeaponSkills::SourceStore::Database.new
      titles = Weapon.pluck(:id, :wiki_en).to_h
      notes_source = lambda do |weapon_id|
        title = titles[weapon_id]
        title.present? ? store.fetch("expanded", title).body : nil
      rescue WeaponSkills::SourceStore::SourceMissing
        nil
      end
    end

    comparison = WeaponSkills::Build::Rows::Comparison.new(weapon_ids: ids, series: series,
                                                           notes_source: notes_source).run
    comparison.write unless ids || series
    counts = comparison.counts
    puts "compare_rows: #{counts[:versions]} versions, #{counts[:rows_today]} rows today, " \
         "#{counts[:rows_compiled]} compiled, #{counts[:rows_equal]} equal"
    diffs = counts.select { |k, _| k.to_s.start_with?("diff_") }
    puts "differences: #{diffs.empty? ? 'none' : diffs.map { |k, n| "#{k.to_s.delete_prefix('diff_')}=#{n}" }.join(', ')}"
    comparison.differences.reject { |d| d["class"] == "notes" && ENV["verbose"] != "true" }.each do |d|
      change = d.except("key", "class", "reason")
      puts "  [#{d['class']}] #{d['key']} #{JSON.generate(change).truncate(300)}#{" — #{d['reason']}" if d['reason']}"
    end
    exit(1) if comparison.unknown.any?
  end
end
