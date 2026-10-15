# frozen_string_literal: true

namespace :granblue do
  desc "Fill weapon_skill_versions.description_en/_jp with each tier's own text from stored sources " \
       "(offline). DRY_RUN=1 reports only; FORCE=1 rewrites filled versions; WEAPON=<granblue_id>; " \
       "REPORT=<path> writes the fallback list as JSON."
  task backfill_version_descriptions: :environment do
    result = WeaponSkills::VersionText::Backfill.run(
      force: ENV["FORCE"] == "1", dry_run: ENV["DRY_RUN"] == "1",
      weapon_ids: ENV["WEAPON"].presence&.split(",")
    )

    puts "versions #{ENV['DRY_RUN'] == '1' ? 'checked' : 'written'}: " \
         "#{result.en_sources.values.sum} (#{result.written} written)"
    puts "en sources: #{result.en_sources.sort.to_h}"
    puts "jp sources: #{result.jp_sources.sort.to_h}"
    puts "fallbacks by page kind: #{result.fallbacks.map { |f| f[:page_kind] }.tally.sort.to_h}"
    puts "weapons whose page could not be parsed offline: #{result.weapon_errors.size}"
    result.weapon_errors.first(10).each { |e| puts "  #{e[:weapon_granblue_id]}: #{e[:error]}" }

    if (path = ENV["REPORT"].presence)
      report = { en_sources: result.en_sources.sort.to_h, jp_sources: result.jp_sources.sort.to_h,
                 fallbacks: result.fallbacks, weapon_errors: result.weapon_errors }
      File.write(path, "#{JSON.pretty_generate(report)}\n")
      puts "report: #{path}"
    end
  end
end
