# frozen_string_literal: true

require 'rails_helper'

# GET /gacha/catalogue: the response keys and what q matches.
RSpec.describe 'Gacha catalogue', type: :request do
  let(:sword) do
    { 'identity' => 'Weapon:00000000-0000-0000-0000-000000000011', 'drawable_type' => 'Weapon',
      'category' => 'characterWeapon', 'rarity' => 3, 'promotions' => [1], 'granblue_id' => '1040000011',
      'name' => { 'en' => 'Blade', 'ja' => '剣' }, 'recruits' => { 'en' => 'Katalina', 'ja' => 'カタリナ' } }
  end
  let(:stone) do
    { 'identity' => 'Summon:00000000-0000-0000-0000-000000000012', 'drawable_type' => 'Summon',
      'category' => 'summon', 'rarity' => 3, 'promotions' => [1], 'granblue_id' => '2040000012',
      'name' => { 'en' => 'Stone', 'ja' => '石' } }
  end
  let(:snapshot) { { 'items' => [sword, stone], 'fingerprint' => 'print', 'loaded_at' => 1_700_000_000 } }

  before do
    allow(GachaSimulation::Catalogue).to receive(:snapshot).and_return(snapshot)
  end

  def matches(query)
    get '/api/v1/gacha/catalogue', params: { q: query }
    response.parsed_body['items'].pluck('granblue_id')
  end

  it 'returns the modes, seasons, items and catalogue details' do
    get '/api/v1/gacha/catalogue'

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq(
      'modes' => GachaSimulation::Configuration::MODES.keys,
      'seasons' => GachaSimulation::Configuration::SEASONS.keys,
      'items' => [sword, stone], 'catalogue_fingerprint' => 'print', 'loaded_at' => 1_700_000_000,
      'banner' => nil, 'label' => 'Hypothetical catalogue simulations'
    )
  end

  it 'matches q against identity, granblue id, names and recruits, ignoring case' do
    expect(matches('summon:')).to eq(['2040000012'])
    expect(matches('1040000011')).to eq(['1040000011'])
    expect(matches('STONE')).to eq(['2040000012'])
    expect(matches('剣')).to eq(['1040000011'])
    expect(matches('katalina')).to eq(['1040000011'])
    expect(matches('カタリナ')).to eq(['1040000011'])
    expect(matches('0000-0000')).to eq(%w[1040000011 2040000012])
    expect(matches('nothing')).to eq([])
  end

  it 'only reads the first 100 characters of q' do
    stone['name']['en'] = 'a' * 100

    expect(matches("#{'A' * 100}zzz")).to eq(['2040000012'])
  end
end
