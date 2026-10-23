require 'rails_helper'
require Rails.root.join('lib/granblue/classic_lower_catalogue')

RSpec.describe Granblue::ClassicLowerCatalogue do
  let!(:weapon) { create(:weapon, rarity: 1, promotions: [1, 99], release_date: Date.new(2014, 3, 10)) }
  let(:entry) do
    { 'type' => 'Weapon', 'granblue_id' => weapon.granblue_id, 'rarity' => 1,
      'evidence' => { 'kind' => 'catalogue_release_date', 'date' => '2014-03-10' } }
  end
  subject(:service) { described_class.new(manifest: { 'entries' => [entry] }) }

  it 'adds all three shared Classic memberships, preserves unrelated flags and reruns' do
    expect(service.preview.first[:after]).to eq([1, 99, 2, 3, 12])
    service.apply!
    service.apply!
    expect(weapon.reload.promotions).to eq([1, 99, 2, 3, 12])
  end

  it 'rejects SSR, source drift and post-cutoff evidence' do
    weapon.update_column(:rarity, 3)
    expect { service.apply! }.to raise_error(/Ordinary lower rarity drift/)
    weapon.update_column(:rarity, 1)
    weapon.update_column(:release_date, Date.new(2015, 1, 1))
    expect { service.apply! }.to raise_error(/Release date drift/)
    entry['evidence']['date'] = '2026-03-10'
    expect { service.apply! }.to raise_error(/Post-cutoff evidence/)
  end

  it 'rejects duplicate identifiers before changes' do
    duplicate = described_class.new(manifest: { 'entries' => [entry, entry] })
    expect { duplicate.apply! }.to raise_error(/Duplicate Classic lower identifiers/)
    expect(weapon.reload.promotions).to eq([1, 99])
  end

  it 'checks canonical recruitment dates instead of inventing weapon release dates' do
    character = create(:character, rarity: 1, element: weapon.element, season: nil, release_date: Date.new(2015, 1, 1))
    weapon.update_columns(recruits: character.granblue_id, release_date: nil)
    entry['evidence'] = { 'kind' => 'recruited_character_release_date', 'recruits' => character.granblue_id, 'date' => '2015-01-01' }
    service.apply!
    expect(weapon.reload.release_date).to be_nil
    character.update_column(:release_date, Date.new(2015, 2, 1))
    expect { service.apply! }.to raise_error(/Character release date drift/)
  end

  it 'accepts reviewed historical page existence without setting an unknown release date' do
    weapon.update_column(:release_date, nil)
    entry['evidence'] = { 'kind' => 'wiki_page_existence', 'date' => '2019-10-31', 'source' => 'https://gbf.wiki/Kila?oldid=304560' }
    service.apply!
    expect(weapon.reload.promotions).to include(2, 3, 12)
    expect(weapon.release_date).to be_nil
  end
end
