require 'rails_helper'
require Rails.root.join('db/data/20261003120000_restore_limited_weapon_pools')

RSpec.describe RestoreLimitedWeaponPools do
  subject(:migration) { described_class.new }

  let!(:weapons) do
    described_class::CHANGES.to_h do |change|
      attributes = { name_en: change[:name], recruits: change[:recruits], promotions: change[:before] }
      # The canonical seed already carries some of these weapons.
      weapon = Weapon.find_by(granblue_id: change[:granblue_id])&.tap { |row| row.update_columns(attributes) }
      [change[:granblue_id], weapon || create(:weapon, granblue_id: change[:granblue_id], **attributes)]
    end
  end

  it 'moves every weapon to its limited pool, rerunnably' do
    2.times do
      migration.up
      expect(weapons['1040008700'].reload.promotions).to eq([4])
      expect(weapons['1040609700'].reload.promotions).to eq([5])
      expect(weapons['1040905700'].reload.promotions).to eq([7])
      expect(weapons['1030604900'].reload.promotions).to eq([7])
      expect(weapons['1040506300'].reload.promotions).to eq([8])
      expect(weapons['1040508700'].reload.promotions).to eq([9])
      expect(weapons['1040414000'].reload.promotions).to eq([6])
      expect(weapons.values.map { |weapon| weapon.reload.promotions & [1, 2, 3, 12] }.uniq).to eq([[]])
    end
  end

  it 'leaves other items untouched' do
    weapon = create(:weapon, promotions: [3])
    migration.up
    expect(weapon.reload.promotions).to eq([3])
  end

  it 'aborts before writing when a weapon is in unexpected pools' do
    weapons['1040414000'].update_column(:promotions, [3, 12])
    expect { migration.up }.to raise_error(/Pool drift for 1040414000/)
    expect(weapons['1040008700'].reload.promotions).to eq([3])
  end

  it 'aborts before writing when a weapon recruits someone unexpected' do
    weapons['1040705400'].update_column(:recruits, '3049999999')
    expect { migration.up }.to raise_error(/Recruitment mismatch for 1040705400/)
    expect(weapons['1040008700'].reload.promotions).to eq([3])
  end

  it 'aborts before writing when a weapon has a different name' do
    weapons['1040414000'].update_column(:name_en, 'Not Medusiana Staff')
    expect { migration.up }.to raise_error(/Name mismatch for 1040414000/)
    expect(weapons['1040008700'].reload.promotions).to eq([3])
  end
end
