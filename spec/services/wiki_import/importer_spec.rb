# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WikiImport::Importer do
  include_context 'with a wiki import catalogue'

  let(:user) { create(:user) }

  def importer(overrides = {}, owner = nil)
    described_class.new(WikiImport::Payload.parse('wiki' => wiki.merge(overrides)), user: owner)
  end

  def codes(report)
    report[:warnings].map { |w| w[:code] }
  end

  describe '#preview' do
    it 'matches every title and identifier without warnings' do
      report = importer.preview

      expect(report[:unmatched]).to eq([])
      expect(report[:ambiguous]).to eq([])
      expect(report[:warnings]).to eq([])
      expect(report[:matched].map { |m| [m[:kind], m[:position]] }).to contain_exactly(
        ['job', 0], ['skill', 1], ['skill', 2], ['accessory', 0],
        ['character', 0], ['character', 1],
        ['weapon', -1], ['weapon', 0], ['weapon', 1],
        ['summon', -1], ['summon', 6], ['summon', 0],
        ['key', 0], ['key', 1], ['key', 0], ['key', 1],
        ['bullet', 0], ['bullet', 1]
      )
    end

    it 'gives the element from the title suffix for weapons and the own element otherwise' do
      matched = importer.preview[:matched]
      gun = matched.find { |m| m[:kind] == 'weapon' && m[:position] == -1 }
      sword = matched.find { |m| m[:kind] == 'weapon' && m[:position] == 1 }
      seofon_entry = matched.find { |m| m[:kind] == 'character' && m[:position] == 0 }

      expect(gun[:item]).to eq(id: ultima_gun.id, granblueId: ultima_gun.granblue_id,
                               name: { en: 'WI Ultima Gun', ja: ultima_gun.name_jp }, element: 1)
      expect(gun[:title]).to eq('WI Ultima Gun (Fire)')
      expect(sword[:item][:element]).to be_nil
      expect(seofon_entry[:item][:element]).to eq(4)
    end

    it 'writes nothing' do
      expect { importer.preview }.not_to(change do
        [Party.count, GridCharacter.count, GridWeapon.count, GridSummon.count, GridWeaponBullet.count]
      end)
    end

    it 'reports ambiguous and unmatched titles and keeps the rest' do
      create(:character, name_en: 'WI Sandalphon', wiki_en: 'WI Sandalphon')
      create(:character, name_en: 'WI Sandalphon', wiki_en: 'WI Sandalphon', style_swap: true)
      characters = wiki['characters'] + [
        { 'position' => 2, 'title' => 'WI Sandalphon' },
        { 'position' => 3, 'title' => 'Not A Character' }
      ]

      report = importer('characters' => characters).preview

      expect(report[:ambiguous]).to contain_exactly(
        hash_including(kind: 'character', position: 2, title: 'WI Sandalphon',
                       candidates: contain_exactly(hash_including(:id, :granblueId, :name, :element),
                                                   hash_including(:id, :granblueId, :name, :element)))
      )
      expect(report[:unmatched]).to eq([{ kind: 'character', position: 3, title: 'Not A Character' }])
      expect(report[:matched].count { |m| m[:kind] == 'character' }).to eq(2)
    end

    it 'matches name_en when wiki_en is blank' do
      ultima_sword.update_column(:wiki_en, '')

      matched = importer.preview[:matched]

      expect(matched.find { |m| m[:kind] == 'weapon' && m[:position] == 1 }[:item][:id]).to eq(ultima_sword.id)
    end

    it 'does not change the element of a weapon whose element is fixed' do
      weapons = [{ 'position' => 0, 'title' => 'WI Staff of Renunciation (Fire)' }]

      report = importer('weapons' => weapons, 'bullets' => []).preview

      expect(report[:matched].find { |m| m[:kind] == 'weapon' }[:item][:element]).to be_nil
      expect(codes(report)).to include('element_not_changeable')
    end

    it 'rejects key ids from another series, keys in the wrong slot and unknown groups' do
      keys = { 'opus' => [915_001, 913_002], 'ultima' => [nil, 999_999], 'befoulment' => [1] }

      report = importer('keys' => keys).preview

      expect(report[:warnings]).to contain_exactly(
        { code: 'unknown_key', detail: 'opus slot 0', kind: 'key', position: 0, title: '915001' },
        { code: 'unknown_key', detail: 'opus slot 1', kind: 'key', position: 1, title: '913002' },
        { code: 'unknown_key', detail: 'ultima slot 1', kind: 'key', position: 1, title: '999999' },
        { code: 'unknown_key', detail: 'befoulment', kind: 'key', title: 'befoulment' }
      )
      expect(report[:matched].none? { |m| m[:kind] == 'key' }).to be(true)
    end

    it 'warns on unknown bullets, classes, skills and accessories' do
      job_spec = { 'name' => 'Not A Class', 'accessory' => 'Not A Shield', 'skills' => ['Not A Skill'] }

      report = importer('job' => job_spec, 'bullets' => %w[forged-bullet]).preview

      expect(codes(report)).to contain_exactly('unknown_job', 'unknown_skill', 'unknown_accessory',
                                               'unknown_bullet')
    end

    it 'tells a skill or accessory that exists but does not fit apart from an unknown one' do
      other_job = create(:job, name_en: 'WI Viking', accessory: false, accessory_type: 0)

      report = importer('job' => wiki['job'].merge('name' => 'WI Viking', 'skills' => ['WI Bazooka'])).preview

      expect(report[:warnings]).to contain_exactly(
        { code: 'skill_not_allowed', detail: other_job.name_en, kind: 'skill', position: 1, title: 'WI Bazooka' },
        { code: 'accessory_not_allowed', detail: other_job.name_en, kind: 'accessory', position: 0,
          title: " WI Hero's Shield " }
      )
    end

    it 'tells an awakening the weapon cannot take apart from an unknown one' do
      weapons = [{ 'position' => -1, 'title' => 'WI Ultima Gun (Fire)', 'awakening' => 'defense' },
                 { 'position' => 0, 'title' => 'WI Staff of Renunciation', 'awakening' => 'sparkle' }]

      report = importer('weapons' => weapons).preview

      expect(report[:warnings]).to contain_exactly(
        { code: 'awakening_not_allowed', detail: 'defense', kind: 'weapon', position: -1,
          title: 'WI Ultima Gun (Fire)' },
        { code: 'unknown_awakening', detail: 'sparkle', kind: 'weapon', position: 0,
          title: 'WI Staff of Renunciation' }
      )
    end

    it 'rejects a skill the class cannot equip' do
      other_main = create(:job_skill, job: create(:job), name_en: 'WI Other Main', main: true)

      report = importer('job' => wiki['job'].merge('skills' => [other_main.name_en])).preview

      expect(report[:warnings]).to eq([{ code: 'skill_not_allowed', detail: 'WI Soldier', kind: 'skill',
                                        position: 1, title: 'WI Other Main' }])
    end

    it 'reports two entries in one position as a slot conflict' do
      summons = wiki['summons'] + [{ 'position' => 0, 'title' => 'WI Lucifer' }]

      expect(importer('summons' => summons).preview[:warnings])
        .to eq([{ code: 'slot_conflict', detail: 'summon 0', kind: 'summon', position: 0, title: 'WI Lucifer' }])
    end
  end

  describe 'preview and create on items the grid models reject' do
    let(:limited_series) { create(:weapon_series) }
    let(:messy) do
      create(:weapon, name_en: 'WI Katana', wiki_en: 'WI Katana', proficiency: 10)
      create(:weapon, name_en: 'WI Limited A', wiki_en: 'WI Limited A', limit: true, weapon_series: limited_series)
      create(:weapon, name_en: 'WI Limited B', wiki_en: 'WI Limited B', limit: true, weapon_series: limited_series)
      {
        'characters' => wiki['characters'] + [{ 'position' => 2, 'title' => 'WI Seofon' }],
        'bullets' => [],
        'weapons' => [
          { 'position' => -1, 'title' => 'WI Katana' },
          { 'position' => 0, 'title' => 'WI Limited A' },
          { 'position' => 1, 'title' => 'WI Limited B' }
        ]
      }
    end

    def counts
      [Party, GridCharacter, GridWeapon, GridSummon, GridWeaponBullet, WeaponKeySeries].map(&:count)
    end

    it 'reports the same warnings in both modes and preview leaves nothing behind' do
      preview_report = nil
      expect { preview_report = importer(messy).preview }.not_to(change { counts })
      _party, create_report = importer(messy.merge('preview' => false)).create!

      expect(preview_report[:warnings]).to eq(create_report[:warnings])
      expect(preview_report[:warnings].select { |w| w[:code] == 'invalid_item' }
        .map { |w| [w[:kind], w[:position]] }).to contain_exactly(['character', 2], ['weapon', -1], ['weapon', 1])
    end
  end

  describe '#create!' do
    subject(:result) { importer({ 'preview' => false }, user).create! }

    let(:party) { result.first.reload }

    it 'creates the party in one go for the user' do
      expect(party.user).to eq(user)
      expect(party.edit_key).to be_nil
      expect(result.last[:warnings]).to eq([])
    end

    it 'sets the class, subskills, accessory and MC full auto' do
      expect(party.job).to eq(job)
      expect(party.skill0).to eq(main_skill)
      expect([party.skill1, party.skill2, party.skill3]).to eq([sub_skill, emp_skill, nil])
      expect(party.accessory).to eq(accessory)
      expect(party.full_auto_skills).to eq('0' => false, '2' => false)
    end

    it 'builds the characters' do
      first = party.characters.find_by(position: 0)
      second = party.characters.find_by(position: 1)

      expect(first).to have_attributes(character: seofon, uncap_level: 6, transcendence_step: 3,
                                       perpetuity: true, full_auto_skills: { '0' => false, '2' => false })
      expect(first.awakening.slug).to eq('character-atk')
      expect(second).to have_attributes(character: tikoh, uncap_level: 4, transcendence_step: 0, perpetuity: false)
      expect(second.awakening.slug).to eq('character-balanced')
    end

    it 'builds the weapons with element, awakening and keys on every weapon of the series' do
      mainhand = party.weapons.find_by(position: -1)
      staff = party.weapons.find_by(position: 0)
      sword = party.weapons.find_by(position: 1)

      expect(mainhand).to have_attributes(weapon: ultima_gun, mainhand: true, uncap_level: 4, element: 1,
                                          weapon_key1_id: will_key.id, weapon_key2_id: ca_key.id)
      expect(sword).to have_attributes(uncap_level: 5, element: nil,
                                       weapon_key1_id: will_key.id, weapon_key2_id: ca_key.id)
      expect(staff).to have_attributes(uncap_level: 6, transcendence_step: 2, awakening: weapon_skill_awakening,
                                       weapon_key1_id: opus_skill_key.id, weapon_key2_id: opus_stamina_key.id)
    end

    it 'puts the bullets on the mainhand in slots of their type' do
      mainhand = party.weapons.find_by(position: -1)

      expect(mainhand.grid_weapon_bullets.order(:position).map { |b| [b.position, b.bullet] })
        .to eq([[0, chaos_legion], [1, chaser]])
    end

    it 'builds the summons with the quick summon' do
      main = party.summons.find_by(position: -1)
      support = party.summons.find_by(position: 6)
      sub = party.summons.find_by(position: 0)

      expect(main).to have_attributes(summon: bahamut, main: true, quick_summon: true, uncap_level: 5)
      expect(support).to have_attributes(summon: lucifer, friend: true, uncap_level: 6, transcendence_step: 5)
      expect(sub).to have_attributes(summon: agni, uncap_level: 4, quick_summon: false)
    end

    it 'makes an anonymous party with an edit key' do
      anonymous_party, = importer('preview' => false).create!

      expect(anonymous_party.user).to be_nil
      expect(anonymous_party.edit_key).to be_present
    end

    it 'skips a grid item the models reject and keeps the rest' do
      weapons = wiki['weapons'] + [{ 'position' => 10, 'title' => 'WI Agni Sword' }]
      create(:weapon, name_en: 'WI Agni Sword', wiki_en: 'WI Agni Sword')

      created, report = importer('preview' => false, 'weapons' => weapons).create!

      expect(created.weapons.count).to eq(3)
      expect(report[:warnings]).to contain_exactly(
        hash_including(code: 'invalid_item', kind: 'weapon', position: 10, title: 'WI Agni Sword')
      )
      expect(report[:warnings].first[:detail]).to start_with('weapon 10:')
    end

    it 'reads a missing uncap the way the wiki renders it, per kind' do
      characters = [{ 'position' => 0, 'title' => 'WI Seofon' }]
      weapons = [{ 'position' => 0, 'title' => 'WI Staff of Renunciation' },
                 { 'position' => 1, 'title' => 'WI Ultima Sword' }]
      summons = [{ 'position' => 6, 'title' => 'WI Lucifer' }, { 'position' => 0, 'title' => 'WI Agni' }]

      created, report = importer('preview' => false, 'characters' => characters, 'weapons' => weapons,
                                 'summons' => summons, 'bullets' => []).create!

      expect(report[:warnings]).to eq([])
      # Characters: base art, at most 4★, even when they can transcend.
      expect(created.characters.sole).to have_attributes(uncap_level: 4, transcendence_step: 0)
      # Weapons: max without transcendence.
      expect(created.weapons.find_by(position: 0)).to have_attributes(uncap_level: 5, transcendence_step: 0)
      expect(created.weapons.find_by(position: 1)).to have_attributes(uncap_level: 5, transcendence_step: 0)
      # Summons: the full max, transcendence included.
      expect(created.summons.find_by(position: 6)).to have_attributes(uncap_level: 6, transcendence_step: 5)
      expect(created.summons.find_by(position: 0)).to have_attributes(uncap_level: 5, transcendence_step: 0)
    end

    it 'reads a missing uncap on a character below 4★ max as its max' do
      low = create(:character, :r, name_en: 'WI Low', wiki_en: 'WI Low', flb: false, special: true)
      characters = [{ 'position' => 0, 'title' => low.wiki_en }]

      created, = importer('preview' => false, 'characters' => characters).create!

      expect(created.characters.sole).to have_attributes(uncap_level: 3, transcendence_step: 0)
    end

    it 'lowers uncaps past the item max and says so' do
      characters = [{ 'position' => 0, 'title' => 'WI Tikoh', 'uncap' => 't2' }]

      created, report = importer('preview' => false, 'characters' => characters).create!

      expect(created.characters.first).to have_attributes(uncap_level: 5, transcendence_step: 0)
      expect(report[:warnings]).to eq([{ code: 'uncap_clamped', detail: 'character 0', kind: 'character',
                                        position: 0, title: 'WI Tikoh' }])
    end
  end
end
