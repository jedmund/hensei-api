# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/data/20261102170100_add_exo_crucible_raids')

RSpec.describe AddExoCrucibleRaids do
  subject(:migration) { described_class.new }

  before { allow(migration).to receive(:say) }

  it 'adds five raids per boss to its group, rerunnably' do
    2.times { migration.up }

    expect(Raid.where('slug LIKE ?', 'exo-%').count).to eq(30)
    expect(Raid.find_by!(slug: 'exo-diablo-lv200')).to have_attributes(
      name_en: 'Exo Diablo Lv200', name_jp: 'エクス・ディアボロス Lv200',
      short_name_en: 'Lv200', short_name_jp: 'Lv200',
      level: 200, element: 6, player_count: 1
    )
    expect(Raid.find_by!(slug: 'exo-ifrit-zenith')).to have_attributes(
      name_en: 'Exo Ifrit Zenith', name_jp: 'エクス・イフリート 廻滅領域',
      short_name_en: 'Zenith Domain', short_name_jp: '廻滅領域', level: nil, element: 1
    )
  end

  it 'uses an existing group and puts the groups in element order after Dread Barrage and Unite and Fight' do
    existing = create(:raid_group, name_en: 'Exo Vohu Manah Crucible', name_jp: 'エクス・ウォフマナフ神滅戦',
                                   section: 2, order: 6)
    migration.up

    expect(Raid.find_by!(slug: 'exo-vohu-manah-lv80').group).to eq(existing)
    expect(RaidGroup.where('name_en LIKE ?', 'Exo %').order(:order).pluck(:name_en, :order)).to eq(
      [['Exo Ifrit Crucible', 3], ['Exo Cocytus Crucible', 4], ['Exo Vohu Manah Crucible', 5],
       ['Exo Sagittarius Crucible', 6], ['Exo Corow Crucible', 7], ['Exo Diablo Crucible', 8]]
    )
  end

  it 'leaves a raid an editor already made alone' do
    group = create(:raid_group, name_en: 'Exo Corow Crucible', section: 2)
    edited = create(:raid, slug: 'exo-corow-lv80', group: group, name_en: 'Edited', level: 80, player_count: 1)
    migration.up

    expect(edited.reload.name_en).to eq('Edited')
  end
end
