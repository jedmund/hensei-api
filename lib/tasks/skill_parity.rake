# frozen_string_literal: true

namespace :granblue do
  desc "Compare this database's resolved weapon-skill rows with data/weapon_skill_parity/baseline.json. " \
       "write=true refreshes the baseline; group=series groups the diff; mode=build rebuilds every weapon " \
       "with the weapon-skill build first (inside a rolled-back transaction); baseline=PATH compares " \
       "against another snapshot."
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
    # The build reads stored sources (granblue:fetch_weapon_sources), never the live wiki.
    Granblue::Parsers::Wiki.offline do
      ActiveRecord::Base.transaction do
        case mode
        when "current" then nil
        when "build"
          summary = WeaponSkills::Build::Runner.new(mode: "write", all: true, io: StringIO.new).call
          puts "build failures: #{summary.errors.map { |id, e| "#{id} #{e.class}" }.join(', ')}" if summary.failed.positive?
        else abort "unknown mode=#{mode} (current, build)"
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
