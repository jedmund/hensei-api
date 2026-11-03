# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WeaponSkills::KeyOptions do
  # The shape of a stored expansion's skill table (Scythe of Repudiation, trimmed)
  def row(icon, name, desc, cls: 'skill post pre')
    <<~HTML
      <tr class="#{cls}">
        <td class="skill-icon"><div>[[File:#{icon}.png|50px|link=]]</div></td>
        <td class="skill-name">#{name}</td>
        <td class="skill-desc">#{desc}</td>
      </tr>
    HTML
  end

  def marker(text)
    %(<tr class="skill-upgrade alternate skill-upgrade-text"><td>&nbsp;</td><td>#{text}</td></tr>)
  end

  let(:html) do
    <<~HTML
      <div class="weapon-skills"><table>
      #{row('ws_skill_god_1_3', "Inferno's [[Weapon Skills#Majesty|Majesty]]", 'Big boost to Fire allies')}
      #{row('ws_skill_blank', 'Guiding Revelation', 'A symbol of apocalyptic corruption. Empowered by a chosen pendulum.')}
      #{marker('Alternate skill 1:</td><td>Use [[Dark_Opus_Weapons#Pendulums and Chains|α Pendulum]] to pick this skill:')}
      #{row('ws_skill_normal_limit', 'α Revelation',
            '10% boost to normal attack DMG cap<br /><span class="skill-upgrade-text">Additional charge attack effect:</span><br />' \
            'Gain <span class="image_link"><span class="tooltip">[[File:Status Counter.png|25px]][[Counter|Tank-and-Counter]]' \
            '<span class="tooltiptext">Counters upon taking DMG<span class="hr"></span><strong>Strength</strong>: 350%</span></span></span>.')}
      #{marker('Alternate skill 1 at level 210:</td><td>Upgraded at level 210:')}
      #{row('ws_skill_normal_limit_2', 'α Revelation Ruber', '10% boost to normal attack DMG cap<ref name="GameWith">GameWith</ref>')}
      #{marker('Alternate skill 2:</td><td>Use [[Anklet of Oblivion]] to pick this skill:')}
      #{row('Ws skill job weapon', 'Strife\'s Godstrike I', '10% boost to MC\'s normal attack damage cap')}
      #{row('ws_skill_blank', 'Guiding Gospel', 'A symbol of evolution\'s holy outcome.')}
      </table></div>
    HTML
  end

  describe '.parse' do
    subject(:options) { described_class.parse(html) }

    it 'lists each key option with its upgrades, and none of the base skills' do
      expect(options.pluck(:key_name)).to eq(['α Pendulum', 'Anklet of Oblivion'])
      alpha = options.first[:versions]
      expect(alpha.pluck(:name_en)).to eq(['α Revelation', 'α Revelation Ruber'])
      expect(alpha.map { |v| v.slice(:unlock_level, :min_uncap, :transcendence_stage) })
        .to eq([{ unlock_level: nil, min_uncap: 3, transcendence_stage: 0 },
                { unlock_level: 210, min_uncap: 5, transcendence_stage: 1 }])
      expect(alpha.pluck(:icon)).to eq(%w[skill_normal_limit skill_normal_limit_2])
      expect(options.last[:versions].first[:icon]).to eq('skill_job_weapon')
    end

    it 'keeps the values: tooltips become {{tt}}, images and refs go' do
      first = options.first[:versions].first[:description_en]
      expect(first).to include("'''Additional charge attack effect:'''")
      expect(first).to include("{{tt|[[Counter|Tank-and-Counter]]|Counters upon taking DMG<br />'''Strength''': 350%}}")
      expect(first).not_to include('File:')
      expect(options.first[:versions].last[:description_en]).to eq('10% boost to normal attack DMG cap')

      segments = WeaponSkills::WikiMarkup.segments(first)
      expect(segments).to include(a_hash_including(text: 'Tank-and-Counter', tooltip: a_string_including('350%')))
    end
  end

  describe '.build' do
    let(:series) { create(:weapon_series, has_weapon_keys: true, num_weapon_keys: 2) }
    let!(:weapon) { create(:weapon, weapon_series: series, name_en: 'Scythe of Repudiation', wiki_en: 'Scythe of Repudiation') }
    let!(:alpha) { create(:weapon_key, name_en: 'α Pendulum', slot: 0) }
    let(:store) do
      WeaponSkills::SourceStore::Memory.new.tap { |s| s.put('expanded', 'Scythe of Repudiation', html) }
    end
    let(:io) { StringIO.new }

    it "writes each matched key's skill, reports the rest, and changes nothing on a rerun" do
      summary = described_class.build(store: store, io: io)
      expect(summary.keys).to eq(1)
      expect(io.string).to include('unmatched: Scythe of Repudiation: Anklet of Oblivion')

      row = WeaponKeySkill.find_by!(weapon_granblue_id: weapon.granblue_id, weapon_key: alpha)
      expect(row.versions.pluck('name_en')).to eq(['α Revelation', 'α Revelation Ruber'])

      expect { described_class.build(store: store, io: io) }.not_to(change { row.reload.updated_at })
    end

    it "drops a key the weapon's page no longer lists" do
      stale = create(:weapon_key, name_en: 'β Pendulum', slot: 0)
      WeaponKeySkill.create!(weapon_granblue_id: weapon.granblue_id, weapon_key: stale, versions: [])
      described_class.build(store: store, io: io)
      expect(WeaponKeySkill.where(weapon_granblue_id: weapon.granblue_id).pluck(:weapon_key_id)).to eq([alpha.id])
    end

    it 'leaves weapons without a stored expansion alone' do
      expect(described_class.build(store: WeaponSkills::SourceStore::Memory.new, io: io).weapons).to eq(0)
    end
  end

  describe 'a grid weapon payload' do
    it "carries each key's skill on that weapon, with display segments" do
      series = create(:weapon_series, has_weapon_keys: true, num_weapon_keys: 2)
      weapon = create(:weapon, weapon_series: series, element: 2)
      key = create(:weapon_key, name_en: 'α Pendulum', slot: 0)
      WeaponKeySkill.create!(weapon_granblue_id: weapon.granblue_id, weapon_key: key,
                             versions: [{ 'name_en' => 'α Revelation', 'description_en' => '10% boost',
                                          'icon' => 'skill_normal_limit', 'unlock_level' => nil,
                                          'min_uncap' => 3, 'transcendence_stage' => 0 }])
      grid_weapon = build(:grid_weapon, weapon: weapon, weapon_key1: key, uncap_level: 5)

      json = Api::V1::GridWeaponBlueprint.render_as_hash(grid_weapon, view: :nested)
      skill = json[:weapon_keys].first[:skill_versions].first
      expect(skill).to include(name: { en: 'α Revelation', ja: nil }, icon_stem: 'skill_normal_limit', ordinal: 0)
      expect(skill[:description_segments][:en]).to eq([{ text: '10% boost' }])
    end
  end
end
