require 'rails_helper'
require Rails.root.join('lib/granblue/banner_catalogue_reconciliation')

RSpec.describe Granblue::BannerCatalogueReconciliation do
  let!(:existing) { create(:weapon, granblue_id: '1040999901', rarity: 3, promotions: [3, 10, 99]) }
  let!(:character) { create(:character, granblue_id: '3030999901', rarity: 2, element: 2, season: nil) }
  let(:attributes) do
    { 'granblue_id' => '1030999901', 'name_en' => 'Reviewed Weapon', 'rarity' => 2, 'element' => 2, 'proficiency' => 4,
      'recruits' => character.granblue_id, 'max_level' => 75, 'max_skill_level' => 10, 'source' => 'Game response' }
  end
  let(:manifest) do
    { 'entries' => [
      { 'type' => 'Weapon', 'granblue_id' => existing.granblue_id, 'rarity' => 3, 'category' => 0, 'add_promotion' => 4 },
      { 'type' => 'Weapon', 'granblue_id' => attributes['granblue_id'], 'rarity' => 2, 'category' => 0, 'create' => true, 'add_promotion' => 1 }
    ], 'new_weapons' => [attributes] }
  end
  subject(:service) { described_class.new(manifest: manifest) }

  it 'previews, creates canonical recruits, preserves UUIDs and unrelated promotions, and reruns' do
    expect(service.preview.map { |e| e[:action] }).to eq(%w[update create])
    expect(Weapon.find_by(granblue_id: attributes['granblue_id'])).to be_nil
    id = existing.id
    service.apply!
    expect(existing.reload.promotions).to eq([3, 10, 99, 4])
    expect(existing.id).to eq(id)
    new_weapon = Weapon.find_by!(granblue_id: attributes['granblue_id'])
    expect(new_weapon.recruits).to eq(character.granblue_id)
    expect(new_weapon.promotions).to eq([1])
    service.apply!
    expect(Weapon.find_by!(granblue_id: new_weapon.granblue_id).id).to eq(new_weapon.id)
  end

  it 'fails before writes if recruitment is missing' do
    character.destroy!
    expect { service.apply! }.to raise_error(/Recruitment mismatch/)
    expect(existing.reload.promotions).to eq([3, 10, 99])
  end

  it 'refuses duplicate catalogue identifiers' do
    create(:weapon, granblue_id: existing.granblue_id)
    expect { service.apply! }.to raise_error(/Duplicate catalogue ID/)
  end

  it 'refuses unknown metadata instead of creating placeholder records' do
    manifest['new_weapons'] = []
    expect { service.apply! }.to raise_error(/Missing verified metadata/)
    expect(existing.reload.promotions).to eq([3, 10, 99])
  end

  it 'protects Classic III SSR exclusions' do
    existing.update_column(:promotions, [12])
    expect { service.apply! }.to raise_error(/Classic III SSR exclusion conflict/)
  end

  it 'refuses metadata or rarity drift on rerun' do
    service.apply!
    Weapon.find_by!(granblue_id: attributes['granblue_id']).update_column(:recruits, nil)
    expect { service.apply! }.to raise_error(/Metadata drift/)
  end
end
