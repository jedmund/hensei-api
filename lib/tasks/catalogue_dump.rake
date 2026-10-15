# frozen_string_literal: true

namespace :granblue do
  desc "Write a data-only dump of the game catalogue (no user data) for bin/setup-pipeline-db. " \
       "path=tmp/catalogue.dump; publish=true also uploads it as a draft release catalogue-YYYYMMDD."
  task export_catalogue_dump: :environment do
    path = Rails.root.join(ENV.fetch("path", "tmp/catalogue.dump"))
    FileUtils.mkdir_p(File.dirname(path))
    url = ActiveRecord::Base.connection_db_config.url ||
          "postgres:///#{ActiveRecord::Base.connection_db_config.database}"
    system(*WeaponSkills::CatalogueDump.pg_dump_command(url, path), exception: true)
    puts "Wrote #{path} (#{(File.size(path) / 1024.0 / 1024).round(1)} MB)"
    next unless ENV["publish"] == "true"

    tag = ENV.fetch("tag", WeaponSkills::CatalogueDump.tag_for)
    notes = "Game catalogue only (weapons, skills, summons, characters, jobs, raids). " \
            "Restore with bin/setup-pipeline-db. Source: #{ENV.fetch('source', 'local')}."
    upload = Rails.root.join("tmp", WeaponSkills::CatalogueDump::ASSET)
    FileUtils.cp(path, upload) unless path == upload
    system("gh", "release", "create", tag, upload.to_s, "--draft", "--repo", WeaponSkills::CatalogueDump::REPO,
           "--title", tag, "--notes", notes, exception: true)
    puts "Published draft release #{tag}"
  end
end
