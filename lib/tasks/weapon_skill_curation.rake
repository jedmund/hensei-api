# frozen_string_literal: true

namespace :granblue do
  desc "Export hand-curated weapon-skill rows to data/weapon_skill_curation/ (commit it with your change)"
  task export_weapon_skill_curation: :environment do
    Granblue::CurationSnapshot.export
    overlay = Granblue::CurationSnapshot.load.to_h
    puts "Exported #{overlay['versions'].size} version overrides, #{overlay['effects'].size} effects, " \
         "#{overlay['data'].size} data rows (#{overlay['ops'].size} ops kept)"
  rescue Granblue::CurationSnapshot::Overlay::Invalid => e
    abort e.message
  end

  desc "Apply data/weapon_skill_curation/ to this database (runs after every db:migrate:with_data)"
  task sync_weapon_skill_curation: :environment do
    Granblue::CurationSnapshot.sync
  rescue Granblue::CurationSnapshot::Overlay::Invalid => e
    abort e.message
  end

  desc "List curation in this database that the committed overlay doesn't have. Exits nonzero on drift."
  task weapon_skill_curation_drift: :environment do
    drift = Granblue::CurationSnapshot.drift
    { "missing" => "curated here, not exported", "changed" => "changed here since the export",
      "unapplied" => "in the overlay, not in this database (run granblue:sync_weapon_skill_curation)" }
      .each do |key, heading|
        next if drift[key].empty?

        puts "#{heading}:"
        drift[key].each { |entry| puts "  #{Granblue::CurationSnapshot.describe(entry)}" }
      end
    if drift.values_at("missing", "changed").any?(&:present?)
      abort "Unshipped curation: run rake granblue:export_weapon_skill_curation and commit data/weapon_skill_curation/"
    end
    puts "No unshipped curation."
  rescue Granblue::CurationSnapshot::Overlay::Invalid => e
    abort e.message
  end

  desc "Move data/weapon_skill_curation.json (v1) and pending/ fragments into the per-series overlay files"
  task split_weapon_skill_curation: :environment do
    counts = Granblue::CurationSnapshot.split
    counts.each { |file, n| puts format("%<n>6d  %<file>s", n: n, file: file) }
    puts "#{counts.values.sum} entries in #{counts.size} files"
  rescue Granblue::CurationSnapshot::Overlay::Invalid => e
    abort e.message
  end
end

# Every deploy runs db:migrate:with_data (Railway pre-deploy), so curation committed to
# the overlay reaches prod without a hand-written data migration. The weapon-skill build
# runs after the sync, in WEAPON_SKILL_BUILD's mode (off: nothing; shadow: a report that
# never fails the deploy; write: the stale weapons). It's called here rather than from its
# own enhance block so the order is explicit: rake runs enhance blocks in definition order,
# and build_weapon_skills.rake loads before this file. The character-skill build follows, in
# CHARACTER_SKILL_BUILD's mode, with the same rules.
if Rake::Task.task_defined?("db:migrate:with_data")
  Rake::Task["db:migrate:with_data"].enhance do
    next if Rails.env.test?

    Rake::Task["granblue:sync_weapon_skill_curation"].invoke
    WeaponSkills::Build::Runner.deploy
    CharacterSkills::Build::Runner.deploy_locked
  end
end
