# frozen_string_literal: true

namespace :granblue do
  desc "Resolve unmodeled weapon-skill versions from their descriptions (version-linked data/effects). DRY_RUN=1 to preview."
  task extract_weapon_skill_descriptions: :environment do
    dry = ENV["DRY_RUN"] == "1"
    stats = Granblue::Extractors::WeaponSkillDescriptionExtractor.run(dry_run: dry)
    puts(dry ? "DRY RUN — no rows written" : "Wrote version-linked rows")
    stats.sort_by { |k, _| k.to_s }.each { |k, n| puts "  #{k}: #{n}" }
  end
end
