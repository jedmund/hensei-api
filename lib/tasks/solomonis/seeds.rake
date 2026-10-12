# frozen_string_literal: true

require_relative 'seed_generator'

namespace :solomonis do
  desc <<~DESC
    Regenerate the Evoking Solomonis seed files in db/seed/solomonis/.

    Usage:
      rake solomonis:generate_seeds
      rake solomonis:generate_seeds WIKI_FILE=path/to/Evoking_Solomonis.wikitext
      rake solomonis:generate_seeds GUIDE_EFFECTS_FILE=path/to/solomonis-guide-effects-en.json

    WIKI_FILE:          saved wikitext of the gbf.wiki "Evoking Solomonis" page. Without it the page
                        is fetched with Granblue::Parsers::Wiki (needs the wiki user agent credential).
    GUIDE_EFFECTS_FILE: game snapshot export ({"effects": [{"status_id": …}]}). Without it the game
                        fields are read back from the existing guide_effects.json, so a rerun only
                        refreshes the wiki-derived availability and tags.
    OUT_DIR:            defaults to db/seed/solomonis.

    Reads characters and summons from the database (Evoker granblue_ids, Arcarum summon JP names);
    never writes to it. Prints the wiki match report for guide effects.
  DESC
  task generate_seeds: :environment do
    out_dir = Pathname(ENV.fetch('OUT_DIR', Rails.root.join('db/seed/solomonis').to_s))
    wikitext = if ENV['WIKI_FILE'].present?
                 File.read(ENV.fetch('WIKI_FILE'))
               else
                 Granblue::Parsers::Wiki.new.fetch('Evoking Solomonis')
               end
    effects = if ENV['GUIDE_EFFECTS_FILE'].present?
                JSON.parse(File.read(ENV.fetch('GUIDE_EFFECTS_FILE'))).fetch('effects')
              else
                JSON.parse(out_dir.join('guide_effects.json').read).fetch('guide_effects')
              end

    generator = Solomonis::SeedGenerator.new(wikitext: wikitext, effects: effects)
    FileUtils.mkdir_p(out_dir)
    {
      'blessings.json' => generator.blessings,
      'guide_effects.json' => generator.guide_effects,
      'names.json' => Solomonis::SeedGenerator.names
    }.each do |file, data|
      out_dir.join(file).write("#{JSON.pretty_generate(data)}\n")
      puts "Wrote #{out_dir.join(file)}"
    end

    generator.report.each do |row|
      puts format('%<id>4d %<verdict>-12s %<score>5s  %<game>s', **row, score: row[:score].to_s)
      puts "#{' ' * 24}wiki: #{row[:wiki]}" if row[:wiki]
    end
  end
end
