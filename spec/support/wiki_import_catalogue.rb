# frozen_string_literal: true

# A small catalogue for WikiImport specs, named "WI …" so nothing collides
# with the canonical seed rows, plus the contract's example request built
# against it.
RSpec.shared_context 'with a wiki import catalogue' do
  let(:ultima_series) { WeaponSeries.find_by!(slug: 'ultima') }
  let(:opus_series) { WeaponSeries.find_by!(slug: 'dark-opus') }
  let(:draconic_series) { WeaponSeries.find_by!(slug: 'draconic') }

  let!(:job) do
    create(:job, name_en: 'WI Soldier', row: '4', proficiency1: 1, proficiency2: 2,
                 accessory: true, accessory_type: 1)
  end
  let!(:main_skill) { create(:job_skill, job: job, name_en: 'WI Bazooka', main: true) }
  let!(:sub_skill) { create(:job_skill, job: create(:job), name_en: 'WI Ammunition Belt', sub: true) }
  let!(:emp_skill) { create(:job_skill, job: job, name_en: 'WI Open Fire', emp: true) }
  let!(:accessory) { create(:job_accessory, job: job, name_en: "WI Hero's Shield", accessory_type: 1) }

  let!(:seofon) do
    create(:character, :transcendable, name_en: 'WI Seofon', wiki_en: 'WI Seofon', element: 1)
  end
  let!(:tikoh) { create(:character, name_en: 'WI Tikoh', wiki_en: 'WI Tikoh', element: 1) }

  let!(:ultima_gun) do
    create(:weapon, name_en: 'WI Ultima Gun', wiki_en: 'WI Ultima Gun', weapon_series: ultima_series,
                    element: 0, flb: true, ulb: true, bullet_slots: [2, 3, 3])
  end
  let!(:ultima_sword) do
    create(:weapon, name_en: 'WI Ultima Sword', wiki_en: 'WI Ultima Sword', weapon_series: ultima_series,
                    element: 0, flb: true, ulb: true)
  end
  let!(:opus_staff) do
    create(:weapon, :transcendable, name_en: 'WI Staff of Renunciation', wiki_en: 'WI Staff of Renunciation',
                                    weapon_series: opus_series, element: 5)
  end
  let!(:weapon_skill_awakening) { Awakening.find_by!(slug: 'weapon-skill') }
  let!(:opus_awakening) { create(:weapon_awakening, weapon: opus_staff, awakening: weapon_skill_awakening) }

  let!(:bahamut) { create(:summon, name_en: 'WI Bahamut', wiki_en: 'WI Bahamut', flb: true, ulb: true) }
  let!(:lucifer) do
    create(:summon, name_en: 'WI Lucifer', wiki_en: 'WI Lucifer', flb: true, ulb: true, transcendence: true)
  end
  let!(:agni) { create(:summon, name_en: 'WI Agni', wiki_en: 'WI Agni', flb: true, ulb: true) }

  let!(:opus_skill_key) { wiki_import_key(913_002, 0, opus_series) }
  let!(:opus_stamina_key) { wiki_import_key(914_001, 1, opus_series) }
  let!(:will_key) { wiki_import_key(910_001, 0, ultima_series) }
  let!(:ca_key) { wiki_import_key(911_003, 1, ultima_series) }
  let!(:draconic_key) { wiki_import_key(915_001, 0, draconic_series) }

  let!(:chaos_legion) { Bullet.create!(name_en: 'WI Chaos Legion', slug: 'wi-chaos-legion', bullet_type: 2) }
  let!(:chaser) { Bullet.create!(name_en: 'WI Chaser Shell', slug: 'wi-chaser-shell', bullet_type: 3) }

  let(:wiki) do
    {
      'preview' => true,
      'job' => {
        'name' => 'wi soldier',
        'accessory' => " WI Hero's Shield ",
        'skills' => ['WI Ammunition Belt', 'WI Open Fire', nil],
        'fullAutoOff' => [0, 2]
      },
      'bullets' => %w[wi-chaos-legion wi-chaser-shell],
      'characters' => [
        { 'position' => 0, 'title' => 'WI Seofon', 'uncap' => 't3', 'awakening' => 'attack', 'ring' => true,
          'fullAutoOff' => [0, 2] },
        { 'position' => 1, 'title' => 'WI Tikoh', 'uncap' => nil, 'awakening' => nil, 'ring' => false,
          'fullAutoOff' => [] }
      ],
      'weapons' => [
        { 'position' => -1, 'title' => 'WI Ultima Gun (Fire)', 'uncap' => '4', 'awakening' => nil },
        { 'position' => 0, 'title' => 'WI Staff of Renunciation', 'uncap' => 't2', 'awakening' => 'skill' },
        { 'position' => 1, 'title' => 'WI_Ultima_Sword', 'uncap' => nil, 'awakening' => nil }
      ],
      'keys' => {
        'opus' => [913_002, 914_001],
        'ultima' => [910_001, 911_003]
      },
      'summons' => [
        { 'position' => -1, 'title' => 'WI Bahamut', 'uncap' => nil },
        { 'position' => 6, 'title' => 'WI Lucifer', 'uncap' => 't5' },
        { 'position' => 0, 'title' => 'WI Agni', 'uncap' => '4' }
      ],
      'quick' => -1
    }
  end

  def wiki_import_key(granblue_id, slot, series)
    key = WeaponKey.create!(name_en: "WI Key #{granblue_id}", name_jp: '鍵', slot: slot, group: 1, order: 1,
                            slug: "wi-key-#{granblue_id}", granblue_id: granblue_id)
    WeaponKeySeries.create!(weapon_key: key, weapon_series: series)
    key
  end
end
