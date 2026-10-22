# frozen_string_literal: true

require 'rails_helper'

# D38: a character row's curated Japanese skill text (its jp_skill_text source).
RSpec.describe Granblue::Parsers::CharacterSkills::JpSkillText do
  let(:fixtures) { Rails.root.join('spec/fixtures/character_skills') }
  let(:wiki) { fixtures.join('character-vikala-wikidata.txt').read }
  let(:text) do
    { 'source' => 'official blog', 'skills' => [
      { 'kind' => 'ability', 'position' => 1, 'name_jp' => '公式名', 'description_jp' => '公式説明' },
      { 'kind' => 'support', 'position' => 1, 'name_jp' => '公式サポ', 'description_jp' => 'サポ説明' }
    ] }
  end

  def create_row(**attrs)
    Character.without_skill_build { create(:character, granblue_id: '3040252000', wiki_raw: wiki, **attrs) }
  end

  def slot(character, kind, position)
    Granblue::Parsers::CharacterSkillParser.new(Character.find(character.id)).graph[:slots]
                                           .find { |s| s[:attrs][:kind] == kind && s[:attrs][:position] == position }
  end

  it 'applies to the row that has it (the style row), and only there' do
    base = create_row(style_swap: false)
    style = create_row(style_swap: true, jp_skill_text: text)

    ability = slot(style, 'ability', 1)
    expect(ability[:versions].map { |v| v[:attrs][:name_jp] }).to all(eq('公式名'))
    expect(ability[:versions].first[:attrs][:description_jp]).to eq('公式説明')
    expect(ability[:versions].drop(1).map { |v| v[:attrs][:description_jp] }).to all(be_nil)
    expect(slot(style, 'support', 1)[:versions].first[:attrs]).to include(name_jp: '公式サポ', description_jp: 'サポ説明')
    expect(slot(style, 'ability', 2)[:versions].first[:attrs][:name_jp]).to be_nil

    expect(slot(base, 'ability', 1)[:versions].map { |v| v[:attrs][:name_jp] }).to all(be_nil)
  end

  # Field by field: what the game data gave stays, the rest comes from the curated text.
  it 'loses to game_raw_jp' do
    game = JSON.parse(fixtures.join('character-vikala-gamedata.json').read)
    game['ability']['1']['comment'] = 'ゲーム説明'
    row = create_row(jp_skill_text: text, game_raw_jp: game)

    versions = slot(row, 'ability', 1)[:versions]
    game_filled = versions.select { |v| v[:attrs][:description_jp] == 'ゲーム説明' }
    expect(game_filled).not_to be_empty
    expect(versions.map { |v| v[:attrs][:description_jp] }).not_to include('公式説明')
    expect(versions.map { |v| v[:attrs][:name_jp] }).to all(eq('公式名')) # the game gave no JP name here
  end

  it 'replaces the JP wiki text' do
    allow_any_instance_of(Granblue::Parsers::CharacterSkills::JpLocalizer).to receive(:apply) do |_, slots|
      slots.each { |s| s[:versions].each { |v| v[:attrs][:name_jp] ||= 'ウィキ名' } }
    end
    row = create_row(jp_skill_text: text)

    expect(slot(row, 'ability', 1)[:versions].first[:attrs][:name_jp]).to eq('公式名')
    expect(slot(row, 'ability', 2)[:versions].first[:attrs][:name_jp]).to eq('ウィキ名')
  end

  it 'sets one version when the entry names an ordinal' do
    text['skills'][0]['ordinal'] = 2
    row = create_row(jp_skill_text: text)

    versions = slot(row, 'ability', 1)[:versions]
    expect(versions.map { |v| v[:attrs][:name_jp] }).to eq([nil, '公式名'] + ([nil] * (versions.size - 2)))
    expect(versions[1][:attrs][:description_jp]).to eq('公式説明')
  end

  it 'is a no-op without the source' do
    row = create_row
    expect(slot(row, 'ability', 1)[:versions].map { |v| v[:attrs][:name_jp] }).to all(be_nil)
  end

  it 'joins the fingerprint only when present, and queues a build when written' do
    row = create_row
    fingerprints = CharacterSkills::Build::Fingerprint.new
    before = fingerprints.for(Character.find(row.id))

    expect { Source.put(row, :jp_skill_text, text) }.to have_enqueued_job(CharacterSkills::BuildJob).with(row.id)
    after = fingerprints.for(Character.find(row.id))
    expect(after).not_to eq(before)
    expect(fingerprints.for_relation(Character.where(id: row.id))).to eq(row.id => after)

    Source.put(row, :jp_skill_text, nil, skip_owner_hook: true)
    expect(fingerprints.for(Character.find(row.id))).to eq(before)
  end
end
