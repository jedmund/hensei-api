# frozen_string_literal: true

namespace :granblue do
  desc "Export hand-curated weapon-skill rows to data/weapon_skill_curation.json (commit it with your change)"
  task export_weapon_skill_curation: :environment do
    Granblue::CurationSnapshot.export
    payload = JSON.parse(File.read(Granblue::CurationSnapshot::PATH))
    puts "Exported #{payload['versions'].size} version overrides, #{payload['effects'].size} effects, " \
         "#{payload['data'].size} data rows"
  end

  desc "Apply data/weapon_skill_curation.json to this database (runs after every db:migrate:with_data)"
  task sync_weapon_skill_curation: :environment do
    Granblue::CurationSnapshot.sync
  end

  desc "List curated rows in this database that the committed snapshot doesn't have. Exits nonzero on drift."
  task weapon_skill_curation_drift: :environment do
    drift = Granblue::CurationSnapshot.drift
    { "missing" => "curated here, not exported", "changed" => "changed here since the export",
      "unapplied" => "in the snapshot, not in this database (run granblue:sync_weapon_skill_curation)" }
      .each do |key, heading|
        next if drift[key].empty?

        puts "#{heading}:"
        drift[key].each { |row| puts "  #{[row['weapon'], row['skill'], row['modifier'], row['boost_type']].compact.join(' / ')}" }
      end
    if drift.values_at("missing", "changed").any?(&:present?)
      abort "Unshipped curation: run rake granblue:export_weapon_skill_curation and commit data/weapon_skill_curation.json"
    end
    puts "No unshipped curation."
  end
end

# Every deploy runs db:migrate:with_data (Railway pre-deploy), so curation committed to
# the snapshot reaches prod without a hand-written data migration.
if Rake::Task.task_defined?("db:migrate:with_data")
  Rake::Task["db:migrate:with_data"].enhance do
    Rake::Task["granblue:sync_weapon_skill_curation"].invoke unless Rails.env.test?
  end
end
