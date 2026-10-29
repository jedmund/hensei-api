# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PartyDifficulty::Rules::WeaponTierMatch do
  let(:series) { WeaponSeries.find_by(slug: 'illustrious') || create(:weapon_series, slug: 'illustrious') }

  def grid_weapon(series_id, step)
    weapon = instance_double(Weapon, weapon_series_id: series_id, promotions: [])
    instance_double(GridWeapon, weapon: weapon, transcendence_step: step, uncap_level: 5, awakening_level: 0)
  end

  def party_with(*weapons)
    instance_double(Party, weapons: weapons)
  end

  it 'scores Illustrious steps 3–4 separately from step 5' do
    high = described_class.new(series_slugs: ['illustrious'], min_transcendence_step: 5, max_transcendence_step: 5)
    low = described_class.new(series_slugs: ['illustrious'], min_transcendence_step: 3, max_transcendence_step: 4)
    [0, 1, 2, 3, 4, 5].each do |step|
      party = party_with(grid_weapon(series.id, step))
      expect(high.matching_count(party)).to eq(step == 5 ? 1 : 0)
      expect(low.matching_count(party)).to eq([3, 4].include?(step) ? 1 : 0)
    end
  end

  it 'requires the series and transcendence conditions to match the same weapon' do
    implementation = described_class.new(series_slugs: ['illustrious'], min_transcendence_step: 5)
    party = party_with(grid_weapon(series.id, 0), grid_weapon('another-series', 5))
    expect(implementation.matching_count(party)).to eq(0)
  end

  it 'does not broaden an unknown series slug into every series' do
    implementation = described_class.new(series_slugs: ['unknown-series'], min_transcendence_step: 5)
    expect(implementation.matching_count(party_with(grid_weapon(series.id, 5)))).to eq(0)
  end

  it 'allows a tier rule without a series filter to match every series' do
    implementation = described_class.new(min_transcendence_step: 5)
    expect(implementation.matching_count(party_with(grid_weapon(series.id, 5)))).to eq(1)
  end

  it 'documents the type and example value for every exposed parameter' do
    examples = PartyDifficulty::Rules::EditorDefinitions.examples_for('weapon_tier_match')
    expect(examples.map { |example| example[:params].values_at(:min_transcendence_step, :max_transcendence_step) }).to eq([[5, 5], [3, 4]])
    PartyDifficulty::Rules::EditorDefinitions.all.each do |definition|
      definition.fetch(:parameters).each do |parameter|
        expect(parameter.fetch(:value_type)).to be_present
        expect(parameter).to have_key(:example)
      end
    end
  end
end
