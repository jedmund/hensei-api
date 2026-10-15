# frozen_string_literal: true

namespace :granblue do
  desc "Compare this database's resolved weapon-skill rows with data/weapon_skill_parity/baseline.json. " \
       "write=true refreshes the baseline; group=series groups the diff; mode=extract re-runs the offline " \
       "description extractor first and mode=full_reparse re-runs EntityReparser on every weapon " \
       "(both inside a rolled-back transaction); baseline=PATH compares against another snapshot."
  task skill_parity: :environment do
    ActiveRecord::Base.logger = nil
    mode = ENV.fetch("mode", "current")
    path = ENV["baseline"].presence || WeaponSkills::ParitySnapshot::BASELINE_PATH
    meta = { "git_sha" => `git rev-parse --short HEAD 2>/dev/null`.strip.presence,
             "catalogue" => ENV["CATALOGUE_TAG"].presence || WeaponSkills::CatalogueDump.restored_tag,
             "mode" => mode }.compact

    if ENV["write"] == "true"
      abort "write=true only snapshots the current database (drop mode=)" unless mode == "current"
      WeaponSkills::ParitySnapshot.write(WeaponSkills::ParitySnapshot.capture(meta: meta), path)
      puts "Wrote #{path}"
      next
    end

    after = nil
    # Reparses read stored sources (granblue:fetch_weapon_sources), never the live wiki.
    Granblue::Parsers::Wiki.offline do
      ActiveRecord::Base.transaction do
        case mode
        when "current" then nil
        when "extract" then Granblue::Extractors::WeaponSkillDescriptionExtractor.run
        when "full_reparse"
          failures = Hash.new(0)
          Weapon.where.not(wiki_raw: [nil, ""]).find_each do |w|
            Granblue::EntityReparser.new(w).reparse
          rescue StandardError => e
            failures[e.class.name] += 1
          end
          puts "reparse failures: #{failures}" if failures.any?
        else abort "unknown mode=#{mode} (current, extract, full_reparse)"
        end
        after = WeaponSkills::ParitySnapshot.capture(meta: meta)
        raise ActiveRecord::Rollback
      end
    end

    diff = WeaponSkills::ParitySnapshot.diff(WeaponSkills::ParitySnapshot.read(path), after)
    WeaponSkills::ParitySnapshot.write(diff, WeaponSkills::ParitySnapshot::LAST_DIFF_PATH)
    WeaponSkills::ParityReport.new(diff, group: ENV.fetch("group", nil)).print
    exit(1) unless WeaponSkills::ParitySnapshot.empty_diff?(diff)
  end
end
