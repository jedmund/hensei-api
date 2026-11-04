# frozen_string_literal: true

require 'rails_helper'

# GET /weapon_skill_families: the full row for a family, the sort, and every
# filter.
RSpec.describe 'Weapon skill families index', type: :request do
  before do
    WeaponSkillDatum.create!(modifier: 'alpha', boost_type: 'atk', series: 'normal', size: 'big',
                             formula_type: 'flat', sl15: 18.0)
    WeaponSkillDatum.create!(modifier: 'alpha', boost_type: 'hp', series: 'omega', size: 'small',
                             formula_type: 'enmity', sl15: 3.0, manually_edited_at: Time.current)
    WeaponSkillEffect.create!(modifier: 'Beta', boost_type: 'dmg_cap', series: 'ex', scaling_kind: 'static',
                              value: 10.0, stacking: 'additive')
    WeaponSkillDatum.create!(modifier: 'Might', boost_type: 'atk', series: 'normal', size: 'medium',
                             formula_type: 'flat', sl15: 12.0)

    weapon = create(:weapon)
    ws = WeaponSkill.create!(weapon_granblue_id: weapon.granblue_id, position: 0)
    WeaponSkillVersion.create!(weapon_skill: ws, skill: create(:skill, name_en: 'Tidal Might', name_jp: '渦潮の攻刃'),
                               ordinal: 0, skill_modifier: 'Might')
  end

  def families(**params)
    get '/api/v1/weapon_skill_families', params: params
    response.parsed_body['weapon_skill_families']
  end

  it 'lists every family sorted by modifier, ignoring case' do
    expect(families.pluck('modifier')).to eq(%w[alpha Beta Might])
  end

  it 'aggregates a family from its data rows' do
    expect(families.first).to eq(
      'modifier' => 'alpha', 'display_name' => nil, 'icon_stems' => [],
      'boost_types' => %w[atk hp], 'series' => %w[normal omega], 'sizes' => %w[big small],
      'formula_types' => %w[enmity flat],
      'counts' => { 'data_rows' => 2, 'effect_rows' => 0, 'versions' => 0, 'weapons' => 0 },
      'manually_edited' => true
    )
  end

  it 'aggregates a family from canonical effects and versions' do
    beta, might_row = families.drop(1)
    expect(beta).to include('boost_types' => ['dmg_cap'], 'series' => ['ex'], 'sizes' => [], 'formula_types' => [],
                            'counts' => { 'data_rows' => 0, 'effect_rows' => 1, 'versions' => 0, 'weapons' => 0 },
                            'manually_edited' => false)
    expect(might_row).to include('display_name' => { 'en' => 'Tidal Might', 'ja' => '渦潮の攻刃' },
                                 'counts' => { 'data_rows' => 1, 'effect_rows' => 0, 'versions' => 1,
                                               'weapons' => 1 })
  end

  it 'searches modifiers and display names' do
    expect(families(q: 'ALP').pluck('modifier')).to eq(['alpha'])
    expect(families(q: 'tidal').pluck('modifier')).to eq(['Might'])
    expect(families(q: '渦潮').pluck('modifier')).to eq(['Might'])
    expect(families(q: 'zzz')).to eq([])
  end

  it 'filters by series, size and boost type' do
    expect(families(series: 'omega').pluck('modifier')).to eq(['alpha'])
    expect(families(series: 'ex').pluck('modifier')).to eq(['Beta'])
    expect(families(size: 'medium').pluck('modifier')).to eq(['Might'])
    expect(families(boost_type: 'atk').pluck('modifier')).to eq(%w[alpha Might])
  end

  it 'filters to families with effects or manual edits only when the flag is "true"' do
    expect(families(has_effects: 'true').pluck('modifier')).to eq(['Beta'])
    expect(families(has_effects: '1').size).to eq(3)
    expect(families(manually_edited: 'true').pluck('modifier')).to eq(['alpha'])
    expect(families(manually_edited: 'yes').size).to eq(3)
  end

  it 'combines filters' do
    expect(families(boost_type: 'atk', size: 'big').pluck('modifier')).to eq(['alpha'])
  end

  it 'refuses a q that is not a string' do
    get '/api/v1/weapon_skill_families', params: { q: { a: 'b' } }

    expect(response).to have_http_status(:unprocessable_content)
  end
end
