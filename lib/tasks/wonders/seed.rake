# frozen_string_literal: true

require 'yaml'
require_relative '../../wonders/seed_generator'

namespace :wonders do
  desc <<~DESC
    Regenerate the Wonders catalogue seed (db/data/wonders/catalogue.json) offline.

    Usage:
      bin/rails wonders:generate_seed
      bin/rails wonders:generate_seed WIKI_FILE=… EN_FILES=a.json,b.json JA_FILES=… OVERRIDES_FILE=… OUT_FILE=…

    WIKI_FILE:      saved wikitext of the gbf.wiki "Wonders" page, the master list
                    (default spec/fixtures/wonders/Wonders.wikitext).
    EN_FILES:       comma-separated EN /item/memorial_list/1 responses
                    (default spec/fixtures/wonders/memorial_list.en.json).
    JA_FILES:       comma-separated JA responses (default spec/fixtures/wonders/memorial_list.ja.json
                    and memorial_list.ja.account2, 3 and 4). All captures are merged by item_id.
    OVERRIDES_FILE: hand-maintained ids and corrections (default db/data/wonders/overrides.yml).
    OUT_FILE:       defaults to db/data/wonders/catalogue.json.

    Reads only files: no network and no database. Load the result with the
    LoadWonderCatalogue data migration (or a new one that calls its load!).
  DESC
  task generate_seed: :environment do
    root = Rails.root
    read = ->(key, default) { File.read(ENV.fetch(key, root.join(default).to_s)) }
    captures = lambda do |key, defaults|
      paths = ENV[key].present? ? ENV[key].split(',') : defaults.map { |path| root.join(path).to_s }
      paths.map { |path| JSON.parse(File.read(path.strip)) }
    end

    generator = Wonders::SeedGenerator.new(
      wikitext: read.call('WIKI_FILE', 'spec/fixtures/wonders/Wonders.wikitext'),
      en_captures: captures.call('EN_FILES', Wonders::SeedGenerator::DEFAULT_EN_CAPTURES),
      ja_captures: captures.call('JA_FILES', Wonders::SeedGenerator::DEFAULT_JA_CAPTURES),
      overrides: YAML.safe_load(read.call('OVERRIDES_FILE', 'db/data/wonders/overrides.yml'))
    )
    catalogue = generator.catalogue

    out = Pathname(ENV.fetch('OUT_FILE', root.join('db/data/wonders/catalogue.json').to_s))
    out.write("#{JSON.pretty_generate(catalogue)}\n")
    missing_jp = catalogue['wonders'].select { |w| w['name_jp'].nil? }.pluck('granblue_id')
    puts "Wrote #{out}: #{catalogue['categories'].size} categories, #{catalogue['wonders'].size} Wonders"
    puts "No JA name yet (falls back to EN): #{missing_jp.join(', ')}" if missing_jp.any?
  end
end
