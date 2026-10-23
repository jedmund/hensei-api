require 'rails_helper'
require Rails.root.join('db/data/20261003000001_correct_gacha_pool_registrations')

RSpec.describe CorrectGachaPoolRegistrations do
  subject(:migration) { described_class.new }

  let(:ordinary) { [1, 4, 5, 6, 7, 8, 9] }

  let!(:octavia) { create(:weapon, granblue_id: '1040918400', recruits: '3040644000', promotions: []) }
  let!(:payila) { create(:weapon, granblue_id: '1040119000', recruits: '3040502000', promotions: []) }
  let!(:indala) { create(:weapon, granblue_id: '1040028100', recruits: '3040569000', promotions: [5]) }
  let!(:swan) { create(:weapon, granblue_id: '1040318400', recruits: '3040117000', promotions: [5]) }

  let!(:classic_ii_summons) do
    described_class::CLASSIC_II_SUMMONS.map do |granblue_id, name|
      create(:summon, granblue_id: granblue_id, name_en: name, promotions: ordinary)
    end
  end
  let!(:morrigna) { create(:summon, granblue_id: '2040122000', name_en: 'Morrigna', promotions: [3]) }
  let!(:prometheus) { create(:summon, granblue_id: '2040125000', name_en: 'Prometheus', promotions: [3]) }
  let!(:tart_man) { create(:summon, granblue_id: '2040461000', name_en: 'Ms. Tart Man', promotions: []) }

  it 'applies the reviewed pool and recruitment corrections, rerunnably' do
    2.times do
      migration.up
      expect(octavia.reload.promotions).to eq([4])
      expect(payila.reload.promotions).to eq([5])
      expect(indala.reload.promotions).to eq([])
      expect(swan.reload).to have_attributes(promotions: [5], recruits: '3040551000')
      expect(classic_ii_summons.map { |summon| summon.reload.promotions }.uniq).to eq([[3]])
      expect(morrigna.reload.promotions).to eq([2])
      expect(prometheus.reload.promotions).to eq([2])
      expect(tart_man.reload.promotions).to eq([7])
    end
  end

  it 'keeps pools outside the ones being corrected' do
    octavia.update_column(:promotions, [1])
    classic_ii_summons.first.update_column(:promotions, ordinary + [12])
    migration.up
    expect(octavia.reload.promotions).to eq([1, 4])
    expect(classic_ii_summons.first.reload.promotions).to eq([3, 12])
  end

  it 'leaves other items untouched' do
    weapon = create(:weapon, recruits: '3040117000', promotions: [3])
    summon = create(:summon, promotions: ordinary)
    migration.up
    expect(weapon.reload).to have_attributes(promotions: [3], recruits: '3040117000')
    expect(summon.reload.promotions).to eq(ordinary)
  end

  it 'aborts before writing when an item is missing' do
    tart_man.destroy!
    expect { migration.up }.to raise_error(/Expected exactly one Summon 2040461000/)
    expect(octavia.reload.promotions).to eq([])
  end

  it 'aborts before writing when a weapon recruits someone unexpected' do
    swan.update_column(:recruits, '3049999999')
    expect { migration.up }.to raise_error(/Recruitment mismatch for 1040318400/)
    expect(payila.reload.promotions).to eq([])
  end

  it 'aborts before writing when a summon has a different name' do
    morrigna.update_column(:name_en, 'Not Morrigna')
    expect { migration.up }.to raise_error(/Name mismatch for 2040122000/)
    expect(octavia.reload.promotions).to eq([])
  end
end
