# frozen_string_literal: true

require 'rails_helper'

# Covers Party#create_remapped_substitutions / remap_substitutions_for, which
# fires after_create when a remix has `_source_party_for_remap` set. The amoeba
# config on Party copies the grid items; this callback copies the substitution
# join rows pointing at them.
RSpec.describe 'Party remix substitution remap', type: :model do
  let(:source_party) { create(:party) }
  let(:weapon)       { Weapon.find_by!(granblue_id: '1040611300') }
  let(:other_weapon) { Weapon.find_by!(granblue_id: '1040912100') }

  def remix(source)
    new_party = source.amoeba_dup
    new_party._source_party_for_remap = source
    new_party.save!
    new_party
  end

  it 'recreates substitutions across all three grid types' do
    # Weapon side
    gw   = create(:grid_weapon, party: source_party, weapon: weapon)
    sw   = create(:grid_weapon, party: source_party, weapon: other_weapon, is_substitute: true)
    create(:substitution, grid: gw, substitute_grid: sw, position: 0)

    # Character side
    character        = Character.first
    other_character  = Character.where.not(id: character.id).first
    gc = create(:grid_character, party: source_party, character: character)
    sc = create(:grid_character, party: source_party, character: other_character, is_substitute: true)
    create(:substitution, grid: gc, substitute_grid: sc, position: 0)

    # Summon side
    summon        = Summon.first
    other_summon  = Summon.where.not(id: summon.id).first
    gs = create(:grid_summon, party: source_party, summon: summon)
    ss = create(:grid_summon, party: source_party, summon: other_summon, is_substitute: true)
    create(:substitution, grid: gs, substitute_grid: ss, position: 0)

    new_party = remix(source_party)

    new_party_grid_ids = (new_party.all_characters + new_party.all_weapons + new_party.all_summons).map(&:id)
    remixed_subs = Substitution.where(grid_id: new_party_grid_ids)

    expect(remixed_subs.count).to eq(3)
    expect(remixed_subs.pluck(:grid_type).sort).to eq(%w[GridCharacter GridSummon GridWeapon])
    expect(remixed_subs.pluck(:position).uniq).to eq([0])
  end

  it 'does not duplicate when remixed twice' do
    gw = create(:grid_weapon, party: source_party, weapon: weapon)
    sw = create(:grid_weapon, party: source_party, weapon: other_weapon, is_substitute: true)
    create(:substitution, grid: gw, substitute_grid: sw, position: 0)

    new_party = remix(source_party)
    expect(Substitution.where(grid_id: new_party.all_weapons.pluck(:id)).count).to eq(1)
  end
end
