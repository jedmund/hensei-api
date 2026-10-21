# frozen_string_literal: true

require 'rails_helper'

# Golden snapshots for a style pair: Cidala and her style shift Super Cidala share
# granblue_id 3040377000 but have their own abilities. Each row builds from its own
# wiki_raw and game_raw_en, and the base's icons never reach the style.
#
# character-super-cidala-gamedata.json is the English-shaped copy of the game's own style-2
# response (character-super-cidala-gamedata-jp.json, D39). Regenerate with REGENERATE=1.
RSpec.describe 'CharacterSkillParser golden snapshots for a style shift' do
  granblue_id = '3040377000'
  base_icons = %w[1640_1 1641_1 1642_3 2529_3]
  style_icons = %w[2559_3 2560_3 2561_1]

  let(:fixture_dir) { Rails.root.join('spec/fixtures/character_skills') }
  let(:golden_dir) { fixture_dir.join('golden') }
  # Both rows share one gbf-wiki.com page; the style's skills are in its スタイルシフト section.
  let(:jp_page) { fixture_dir.join('character-cidala-jpwiki.html').read }

  let!(:base) do
    create(:character, granblue_id: granblue_id, name_en: 'Cidala',
                       wiki_raw: fixture_dir.join('character-cidala-wikidata.txt').read,
                       game_raw_en: JSON.parse(fixture_dir.join('character-cidala-gamedata.json').read),
                       game_raw_jp: nil, wiki_raw_jp: jp_page)
  end
  let!(:style) do
    create(:character, granblue_id: granblue_id, name_en: 'Cidala', style_swap: true, style_name_en: 'Super Cidala',
                       wiki_raw: fixture_dir.join('character-super-cidala-wikidata.txt').read,
                       game_raw_en: JSON.parse(fixture_dir.join('character-super-cidala-gamedata.json').read),
                       game_raw_jp: nil, wiki_raw_jp: jp_page)
  end

  before { Granblue::Parsers::StatusCatalogBuilder.build_all }

  def build(character)
    Granblue::Parsers::CharacterSkillParser.new(character.reload).parse
  end

  def lookup
    @lookup ||= Granblue::Parsers::CharacterSkillParser.build_status_lookup
  end

  def expect_golden(key, report)
    snapshot = CharacterSkillGolden.normalize(report, lookup)
    golden = golden_dir.join("#{key}.json")
    if ENV['REGENERATE'] == '1' || !golden.exist?
      golden.write("#{JSON.pretty_generate(snapshot)}\n")
      skip "regenerated golden for #{key}"
    else
      expect(snapshot).to eq(JSON.parse(golden.read))
    end
  end

  it 'matches the golden snapshot for Cidala' do
    expect_golden('cidala', build(base))
  end

  it 'matches the golden snapshot for Super Cidala' do
    expect_golden('super_cidala', build(style))
  end

  it 'builds each row from its own sources' do
    base_report = build(base)
    style_report = build(style)

    aggregate_failures do
      expect(CharacterSkillGolden.ability_icons(base_report)).to include('1640_1')
      expect(CharacterSkillGolden.ability_icons(style_report)).to match_array(style_icons)
      expect(CharacterSkillGolden.ability_icons(style_report) & base_icons).to be_empty
    end
  end

  it "takes the style's icons from its own wiki stems when it has no game data" do
    style.update!(game_raw_en: nil)

    icons = CharacterSkillGolden.ability_icons(build(style))

    aggregate_failures do
      expect(icons).to match_array(style_icons)
      expect(icons & base_icons).to be_empty
    end
  end

  it "ignores the base's game data left on the style row by older writers" do
    style.update!(game_raw_en: base.game_raw_en)

    icons = CharacterSkillGolden.ability_icons(build(style))

    aggregate_failures do
      expect(icons).to match_array(style_icons)
      expect(icons & base_icons).to be_empty
    end
  end

  it "takes each row's JP text from its own section of the shared JP page" do
    jp_names = lambda do |report|
      report[:slots].select { |slot| slot[:attrs][:kind] == 'ability' }
                    .map { |slot| slot[:versions].first[:attrs][:name_jp] }
    end

    aggregate_failures do
      expect(jp_names.call(build(style))).to eq(%w[運気揚々(うんきあげあげ) 開寅招福(かいいんしょうふく) 運気下々(うんきさげさげ)])
      expect(jp_names.call(build(base))).not_to include('運気揚々(うんきあげあげ)')
    end
  end

  it "gives a style row no JP text when the page has no section for it" do
    style.update!(wiki_raw_jp: jp_page.gsub('スタイルシフト「スーパーシンダラ」', '別ページ'))

    names = build(style)[:slots].flat_map { |slot| slot[:versions].map { |v| v[:attrs][:name_jp] } }

    expect(names.compact).to be_empty
  end

  it "persists the two rows' skills independently" do
    Granblue::Parsers::CharacterSkillParser.new(base.reload).parse(persist: true)
    Granblue::Parsers::CharacterSkillParser.new(style.reload).parse(persist: true)

    names = ->(row) { row.character_skills.ability.flat_map { |s| s.character_skill_versions.map(&:name_en) } }
    aggregate_failures do
      expect(names.call(base.reload)).to include('Jinx of the Tiger')
      expect(names.call(style.reload)).to include('Luck Goes Up')
      expect(names.call(style) & names.call(base)).to be_empty
    end
  end
end
