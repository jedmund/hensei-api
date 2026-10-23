# frozen_string_literal: true

namespace :granblue do
  # The stored series pages (W3's source store). Extraction never falls back to the
  # live wiki: without stored sources there is nothing to extract from.
  key_skill_source_store = lambda do
    unless defined?(WeaponSkills::SourceStore::Database)
      abort "Stored weapon sources are not available yet; run granblue:fetch_weapon_sources " \
            "on a build with the weapon source store (pipeline W3, #541)."
    end

    WeaponSkills::SourceStore::Database.new
  end

  desc "Auto-generate element-agnostic key→skill effects from the stored weapon-series pages. DRY_RUN=1 to preview."
  task extract_key_skills: :environment do
    stats, preview = Granblue::Extractors::KeySkillExtractor.run(store: key_skill_source_store.call,
                                                                 dry_run: ENV["DRY_RUN"].present?)
    preview.each { |p| puts "  #{p[:slug].ljust(24)} #{p[:effects].join(', ')}" } if ENV["DRY_RUN"].present?
    puts "Key skill extraction: #{stats.sort_by { |k, _| k.to_s }.to_h.inspect}"
  end

  desc "Run the key extraction in a rolled-back transaction and diff the parity snapshot's keys " \
       "section against the baseline. OUT=path writes the diff as JSON."
  task key_skill_parity: :environment do
    baseline = WeaponSkills::ParitySnapshot.read
    diff = nil
    stats = nil
    ActiveRecord::Base.transaction do
      stats, = Granblue::Extractors::KeySkillExtractor.run(store: key_skill_source_store.call)
      # A full capture so diff checks the column lists; only the keys section is reported.
      diff = WeaponSkills::ParitySnapshot.diff(baseline, WeaponSkills::ParitySnapshot.capture)
      raise ActiveRecord::Rollback
    end

    puts "Key skill extraction (rolled back): #{stats.sort_by { |k, _| k.to_s }.to_h.inspect}"
    if diff["keys"].empty?
      puts "Key parity: no differences across #{baseline.fetch('keys').size} keys"
    else
      diff["keys"].each do |change|
        puts "key #{change['key_slug']}"
        before = Array(change["before"])
        after = Array(change["after"])
        (before - after).each { |row| puts "  - #{row.to_json}" }
        (after - before).each { |row| puts "  + #{row.to_json}" }
      end
      puts "Key parity: #{diff['keys'].size} keys differ"
    end
    WeaponSkills::ParitySnapshot.write(diff["keys"], ENV["OUT"]) if ENV["OUT"].present?
    exit 1 unless diff["keys"].empty?
  end
end
