# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/data/20261102210100_add_records_of_the_ten_raids')

RSpec.describe AddRecordsOfTheTenRaids do
  subject(:migration) { described_class.new }

  before { allow(migration).to receive(:say) }

  it 'adds the five solo raids to one group, rerunnably' do
    2.times { migration.up }

    group = RaidGroup.find_by!(name_en: 'Records of the Ten')
    expect(group).to have_attributes(name_jp: '十天衆イベント', section: 2, order: 9)
    expect(group.raids.order(:level).pluck(:slug, :name_en, :name_jp, :level, :player_count, :element)).to eq(
      [
        ['rott-very-hard', 'Very Hard', 'VERY HARD', 75, 1, 0],
        ['rott-extreme', 'Extreme', 'EXTREME', 80, 1, 0],
        ['rott-impossible', 'Impossible', 'IMPOSSIBLE', 95, 1, 0],
        ['rott-nm100', 'NM100', '100HELL', 100, 1, 0],
        ['rott-nm150', 'NM150', '150HELL', 150, 1, 0]
      ]
    )
  end

  it "keeps an existing group and editors' raids" do
    group = create(:raid_group, name_en: 'Records of the Ten', name_jp: '既存', order: 12)
    create(:raid, slug: 'rott-nm150', name_en: 'Edited', group: group)

    migration.up

    expect(group.reload.order).to eq(12)
    expect(group.raids.count).to eq(5)
    expect(Raid.find_by!(slug: 'rott-nm150').name_en).to eq('Edited')
  end
end
