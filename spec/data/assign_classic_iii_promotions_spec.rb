require 'rails_helper'
require Rails.root.join('db/data/20261002000001_assign_classic_iii_promotions')

RSpec.describe AssignClassicIiiPromotions do
  subject(:migration) { described_class.new }

  let!(:weapon) { create(:weapon, granblue_id: '1040999991', rarity: 3, promotions: [1, 2, 4, 5, 6, 7, 8, 9, 10, 11, 99]) }
  let!(:summon) { create(:summon, granblue_id: '2040999991', rarity: 3, promotions: [1, 4, 10]) }
  let(:manifest) do
    [CSV::Row.new(%w[type granblue_id name availability rarity], ['Weapon', weapon.granblue_id, weapon.name_en, 'exclusive', 'SSR']),
     CSV::Row.new(%w[type granblue_id name availability rarity], ['Summon', summon.granblue_id, summon.name_en, 'shared', 'SSR'])]
  end

  before { allow(CSV).to receive(:read).with(described_class::MANIFEST, headers: true).and_return(manifest) }

  it 'removes ordinary availability only for exclusive entries and preserves other promotions, rerunnably' do
    migration.up
    expect(weapon.reload.promotions).to eq([2, 10, 11, 12, 99])
    expect(summon.reload.promotions).to eq([1, 4, 10, 12])
    migration.up
    expect(weapon.reload.promotions).to eq([2, 10, 11, 12, 99])
    expect(summon.reload.promotions).to eq([1, 4, 10, 12])
  end

  it 'previews without writing and leaves unlisted items untouched' do
    other = create(:weapon, promotions: [1, 3])
    expect(migration.preview.first[:after]).to eq([2, 10, 11, 12, 99])
    expect(weapon.reload.promotions).to include(1)
    migration.up
    expect(other.reload.promotions).to eq([1, 3])
  end

  it 'rejects missing identifiers before changing any rows' do
    summon.destroy!
    expect { migration.up }.to raise_error(/Expected exactly one Summon/)
    expect(weapon.reload.promotions).to include(1)
  end

  it 'rejects duplicate identifiers before changing any rows' do
    create(:weapon, granblue_id: weapon.granblue_id)
    expect { migration.up }.to raise_error(/found 2/)
    expect(weapon.reload.promotions).to include(1)
  end
  it 'rejects catalogue rarity drift' do
    weapon.update_column(:rarity, 2)
    expect { migration.up }.to raise_error(/Rarity mismatch/)
    expect(summon.reload.promotions).to eq([1, 4, 10])
  end

  it 'rejects duplicate manifest identifiers' do
    manifest << manifest.first
    expect { migration.up }.to raise_error(/Duplicate identifiers in Classic III manifest/)
    expect(weapon.reload.promotions).to include(1)
  end

  it 'rejects known recruitment drift' do
    manifest.first['recruits'] = '3040999991'
    expect { migration.up }.to raise_error(/Recruitment mismatch/)
    expect(weapon.reload.promotions).to include(1)
  end
end
