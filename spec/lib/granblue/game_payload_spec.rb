# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::GamePayload do
  let(:jp) { JSON.parse(Rails.root.join('spec/fixtures/character_skills/character-super-cidala-gamedata-jp.json').read) }
  let(:en) { JSON.parse(Rails.root.join('spec/fixtures/character_skills/character-super-cidala-gamedata.json').read) }

  it 'judges the language from the skill names' do
    expect(described_class.language(jp)).to eq('jp')
    expect(described_class.language(en)).to eq('en')
    expect(described_class.language({ 'id' => '1' })).to be_nil
    expect(described_class.language({ 'special_skill' => { 'name' => '奥義' } })).to eq('jp')
  end

  it 'goes by most names, so one Japanese skill name leaves an English payload English' do
    en['ability']['1']['name'] = '運気揚々'
    expect(described_class.language(en)).to eq('en')

    tie = { 'ability' => { '1' => { 'name' => '炎' }, '2' => { 'name' => 'Fire' } } }
    expect(described_class.language(tie)).to be_nil
  end

  describe '.sanitize' do
    # A player-shaped payload, as the game sends it for the player's own copy.
    let(:player_payload) do
      jp.merge('id' => 194_127_733, 'user' => { 'param' => { 'user_id' => '1', 'viewer_id' => '2' } },
               'pushed_npc' => { 'npc_id' => '3' }, 'artifact' => { 'id' => '4' }, 'rank' => '791',
               'possessed_lp' => 7266, 'user_npc_id' => 5,
               'param' => jp['param'].merge('attack' => '19333', 'hp' => '5483', 'level' => '150'))
    end

    it 'keeps only character data' do
      kept = described_class.sanitize(player_payload)

      expect(kept.keys).not_to include('id', 'user', 'pushed_npc', 'artifact', 'rank', 'possessed_lp', 'user_npc_id', '_note')
      expect(described_class.sanitize(player_payload.merge('support_ability_of_npczenith' => { '1' => {} },
                                                           'voice_acter' => 'x', 'pose_list' => [], 'is_zenith_open' => true,
                                                           'episode_rate' => 50, 'npc_arousal_level' => 3)).keys)
        .to include('support_ability_of_npczenith', 'voice_acter', 'pose_list')
        .and(satisfy { |keys| !keys.intersect?(%w[is_zenith_open episode_rate npc_arousal_level]) })
      expect(kept['param'].keys).to contain_exactly('style', 'rarity', 'image_id_9')
      expect(kept.slice(*described_class::SKILL_KEYS, 'master', 'style', 'style_list'))
        .to eq(jp.slice(*described_class::SKILL_KEYS, 'master', 'style', 'style_list'))
      expect([described_class.granblue_id(kept), described_class.style(kept), described_class.language(kept),
              described_class.series_id(kept)]).to eq(%w[3040377000 2 jp 6])
    end

    it "keeps an archive payload's id, which is the character's" do
      archive = JSON.parse(Rails.root.join('spec/fixtures/character_skills/character-vikala-gamedata.json').read)
      expect(described_class.sanitize(archive)).to include('id' => '3040252000')
      expect(described_class.sanitize(archive)).not_to have_key('user_npc_id')
    end

    it 'leaves a non-object as is' do
      expect(described_class.sanitize(nil)).to be_nil
      expect(described_class.sanitize([1])).to eq([1])
    end
  end

  it 'takes the character from master.id and the style from style or param.style' do
    expect(described_class.granblue_id(jp.merge('id' => '194127733'))).to eq('3040377000')
    expect(described_class.granblue_id({ 'id' => '3040377000' })).to eq('3040377000')
    expect(described_class.style(jp)).to eq('2')
    expect(described_class.style({ 'param' => { 'style' => '2' } })).to eq('2')
    expect(described_class.style({})).to eq('')
  end

  it 'reads a malformed body as saying nothing' do
    [nil, [], 'text', { 'master' => 'x', 'param' => [1] }, { 'master' => { 'id' => { 'a' => 1 } } }].each do |body|
      expect([described_class.granblue_id(body), described_class.style(body), described_class.series_id(body)])
        .to eq([nil, '', nil])
    end
    expect(described_class.series_id(jp)).to eq('6')
    expect(described_class.series_id({ 'series_id' => { 'a' => 1 } })).to be_nil
  end
end
