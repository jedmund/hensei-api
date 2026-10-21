# frozen_string_literal: true

require 'rails_helper'

# Characterization (golden-snapshot) test. Locks the exact observable parse output
# — slots, versions, effects (with resolved status names), and links — for the
# sample characters, so the parser can be refactored (e.g. the #5 builder split)
# with proof that behavior is unchanged. Regenerate goldens with REGENERATE=1.
RSpec.describe 'CharacterSkillParser golden snapshots' do
  samples = {
    vikala: { granblue_id: '3040252000', name: 'Vikala' },
    caim: { granblue_id: '3040164000', name: 'Caim' },
    threo: { granblue_id: '3040032000', name: 'Threo' },
    wamdus: { granblue_id: '3040419000', name: 'Wamdus' },
    orologia: { granblue_id: '3040536000', name: 'Orologia' }
  }

  samples.each do |key, sample|
    it "matches the golden snapshot for #{sample[:name]}" do
      snapshot = parse_snapshot(key, sample)
      golden = golden_dir.join("#{key}.json")

      if ENV['REGENERATE'] == '1' || !golden.exist?
        golden.write("#{JSON.pretty_generate(snapshot)}\n")
        skip "regenerated golden for #{key}"
      else
        expect(snapshot).to eq(JSON.parse(golden.read))
      end
    end
  end

  # Stored game payloads keep only character data (Granblue::GamePayload.sanitize); the build
  # must come out the same as from the whole payload.
  it 'builds the same from the whole and the sanitized game payloads' do
    Granblue::Parsers::StatusCatalogBuilder.build_all
    samples.each do |key, sample|
      raw = JSON.parse(File.read(fixture_dir.join("character-#{key}-gamedata.json")))
      whole = create(:character, granblue_id: sample[:granblue_id], wiki_raw: File.read(fixture_dir.join("character-#{key}-wikidata.txt")))
      sanitized = create(:character, granblue_id: sample[:granblue_id], style_swap: false,
                                     wiki_raw: whole.wiki_raw, game_raw_en: raw)
      Source.put(whole, :game_raw_en, raw, skip_owner_hook: true) # bypasses the attribute's sanitizer

      expect(Source.read(sanitized, :game_raw_en).keys).to all(satisfy { |k| raw.key?(k) })
      graph = ->(c) { Granblue::Parsers::CharacterSkillParser.new(Character.find(c.id)).graph }
      expect(graph.call(sanitized)).to eq(graph.call(whole)), "#{key} differs"
    end
  end

  def fixture_dir
    Rails.root.join('spec/fixtures/character_skills')
  end

  def golden_dir
    fixture_dir.join('golden').tap(&:mkpath)
  end

  def parse_snapshot(key, sample)
    jp = fixture_dir.join("character-#{key}-jpwiki.html")
    character = create(
      :character,
      granblue_id: sample[:granblue_id], name_en: sample[:name],
      wiki_raw: File.read(fixture_dir.join("character-#{key}-wikidata.txt")),
      game_raw_en: JSON.parse(File.read(fixture_dir.join("character-#{key}-gamedata.json"))),
      game_raw_jp: nil,
      wiki_raw_jp: (File.read(jp) if File.exist?(jp))
    )
    Granblue::Parsers::StatusCatalogBuilder.build_all
    lookup = Granblue::Parsers::CharacterSkillParser.build_status_lookup
    CharacterSkillGolden.normalize(Granblue::Parsers::CharacterSkillParser.new(character).parse, lookup)
  end
end
