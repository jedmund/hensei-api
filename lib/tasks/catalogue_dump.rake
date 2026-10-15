# frozen_string_literal: true

namespace :granblue do
  desc "Write a data-only dump of the game catalogue (no user data) for bin/setup-pipeline-db. " \
       "path=tmp/catalogue.dump; publish=true also uploads it as a draft release catalogue-YYYYMMDD " \
       "(tag= to name it; refuses a tag that already has a release)."
  task export_catalogue_dump: :environment do
    publish = ENV["publish"] == "true"
    tag = ENV.fetch("tag", WeaponSkills::CatalogueDump.tag_for)
    if publish && WeaponSkills::CatalogueDump.release_exists?(tag)
      abort "A release tagged #{tag} already exists on #{WeaponSkills::CatalogueDump::REPO}. " \
            "Pick another name with tag=, e.g. tag=#{tag}-2."
    end

    path = Rails.root.join(ENV.fetch("path", "tmp/catalogue.dump"))
    FileUtils.mkdir_p(File.dirname(path))
    url = ActiveRecord::Base.connection_db_config.url ||
          "postgres:///#{ActiveRecord::Base.connection_db_config.database}"
    system(*WeaponSkills::CatalogueDump.pg_dump_command(url, path), exception: true)
    puts "Wrote #{path} (#{(File.size(path) / 1024.0 / 1024).round(1)} MB)"
    next unless publish

    notes = "Game catalogue only (weapons, skills, summons, characters, jobs, raids). " \
            "Restore with bin/setup-pipeline-db. Source: #{ENV.fetch('source', 'local')}."
    upload = Rails.root.join("tmp", WeaponSkills::CatalogueDump::ASSET)
    FileUtils.cp(path, upload) unless path == upload
    system("gh", "release", "create", tag, upload.to_s, "--draft", "--repo", WeaponSkills::CatalogueDump::REPO,
           "--title", tag, "--notes", notes, exception: true)
    puts "Published draft release #{tag}"
  end
end
