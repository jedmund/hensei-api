# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Evoking Solomonis seal state and unseal priority', type: :model do
  let(:evoker) { create(:character, :solomonis_evoker) }
  let(:party) { create(:party, :solomonis, route_evoker: evoker) }

  def weapon_at(party, position, **attrs)
    create(:grid_weapon, party: party, weapon: create(:weapon), position: position, **attrs)
  end

  def summon_at(party, position, **attrs)
    create(:grid_summon, party: party, summon: create(:summon, subaura: true), position: position,
                         main: position == -1, **attrs)
  end

  def justice_level
    create(:arcarum_blessing_level, arcarum_blessing: create(:arcarum_blessing, :justice), cost: 50)
  end

  it 'starts the fixed slots and seals the rest by default' do
    states = [-1, 0, 1, 2, 3, 8].to_h { |p| [p, weapon_at(party, p).seal_state] }
    expect(states).to eq(-1 => 'start', 0 => 'start', 1 => 'start', 2 => 'sealed', 3 => 'sealed', 8 => 'sealed')
  end

  it 'starts the main summon only' do
    expect(summon_at(party, -1).seal_state).to eq('start')
    expect(summon_at(party, 0).seal_state).to eq('sealed')
    expect(summon_at(party, 4).seal_state).to eq('sealed')
  end

  it 'records unsealed or sealed on other slots, and null as the default' do
    weapon = weapon_at(party, 4)
    expect(weapon.update(seal_state: 'unsealed')).to be(true)
    expect(weapon.update(seal_state: 'sealed')).to be(true)
    expect(weapon.update(seal_state: 'unsealed')).to be(true)
    expect(weapon.update(seal_state: nil)).to be(true)
    expect(weapon.seal_state).to eq('sealed')
  end

  it 'takes a seal state given on create' do
    expect(weapon_at(party, 4, seal_state: 'unsealed').seal_state).to eq('unsealed')
  end

  it 'rejects start outside a starting slot and anything else on one' do
    expect(weapon_at(party, 4).update(seal_state: 'start')).to be(false)
    expect(weapon_at(party, 0).update(seal_state: 'sealed')).to be(false)
    expect(summon_at(party, -1).update(seal_state: 'unsealed')).to be(false)
  end

  it 'starts position 2 with Justice and seals it again without' do
    weapon = weapon_at(party, 2, seal_state: 'unsealed')
    party.replace_solomonis_blessings!([justice_level])
    expect(weapon.reload.seal_state).to eq('start')
    expect(weapon_at(party.reload, 3).seal_state).to eq('sealed')
    party.reload.replace_solomonis_blessings!([])
    expect(weapon.reload.seal_state).to eq('sealed')
  end

  it 're-derives the state when a weapon moves in or out of a starting slot' do
    weapon = weapon_at(party, 0)
    weapon.update!(position: 5)
    expect(weapon.seal_state).to eq('sealed')
    weapon.update!(seal_state: 'unsealed')
    weapon.update!(position: 6)
    expect(weapon.seal_state).to eq('unsealed')
    weapon.update!(position: 1)
    expect(weapon.seal_state).to eq('start')
  end

  it 'allows unseal priority on sealed slots only' do
    expect(weapon_at(party, 4).update(unseal_priority: 1)).to be(true)
    expect(weapon_at(party, 5, seal_state: 'unsealed').update(unseal_priority: 2)).to be(false)
  end

  it 'drops the priority of a slot that is unsealed' do
    weapon = weapon_at(party, 4)
    other = weapon_at(party, 5)
    party.replace_unseal_priority!([{ type: 'weapon', id: weapon.id }, { type: 'weapon', id: other.id }])
    weapon.reload.update!(seal_state: 'unsealed')
    expect(weapon.unseal_priority).to be_nil
    expect(other.reload.unseal_priority).to eq(1)
  end

  describe '#apply_solomonis_seal_states!' do
    it 'sets imported states by position and keeps starting slots' do
      weapons = [-1, 3, 4].map { |p| weapon_at(party, p) }
      summons = [-1, 0, 4].map { |p| summon_at(party, p) }
      party.apply_solomonis_seal_states!(weapons: { -1 => 'sealed', 3 => 'unsealed', 4 => 'sealed' },
                                         summons: { -1 => 'sealed', 0 => 'unsealed', 4 => 'unsealed' })
      expect(weapons.map { |w| w.reload.seal_state }).to eq(%w[start unsealed sealed])
      expect(summons.map { |s| s.reload.seal_state }).to eq(%w[start unsealed unsealed])
    end
  end

  it 'rejects a support summon on a Solomonis party' do
    summon = build(:grid_summon, party: party, summon: create(:summon), position: 6, friend: true)
    expect(summon).not_to be_valid
    expect(summon.errors[:friend]).to be_present
  end

  it 'keeps the Solomonis fields empty elsewhere' do
    party = create(:party)
    weapon = weapon_at(party, 3)
    expect(weapon.seal_state).to be_nil
    expect(weapon.update(seal_state: 'sealed')).to be(false)
    expect(weapon.update(unseal_priority: 1)).to be(false)
  end

  it 'derives states for an existing grid when the party enters the mode' do
    party = create(:party)
    weapon = weapon_at(party, 4)
    summon = summon_at(party, -1)
    party.reload.update!(solomonis_expedition_attributes: { route_evoker_id: evoker.id })
    expect(weapon.reload.seal_state).to eq('sealed')
    expect(summon.reload.seal_state).to eq('start')
  end

  describe '#replace_unseal_priority!' do
    let!(:w3) { weapon_at(party, 3) }
    let!(:w4) { weapon_at(party, 4) }
    let!(:s0) { summon_at(party, 0) }
    let!(:start_weapon) { weapon_at(party, 0) }

    it 'numbers weapons and summons as separate lists' do
      s1 = summon_at(party, 1)
      party.replace_unseal_priority!([{ type: 'summon', id: s0.id }, { type: 'weapon', id: w4.id },
                                      { type: 'summon', id: s1.id }, { type: 'weapon', id: w3.id }])
      expect([w4, w3, s0, s1].map { |row| row.reload.unseal_priority }).to eq([1, 2, 1, 2])
    end

    it 'gives a weapon and a summon both priority 1' do
      party.replace_unseal_priority!([{ type: 'summon', id: s0.id }, { type: 'weapon', id: w4.id }])
      expect([s0.reload.unseal_priority, w4.reload.unseal_priority, w3.reload.unseal_priority]).to eq([1, 1, nil])
    end

    it 'clears the priority of a type left out' do
      party.replace_unseal_priority!([{ type: 'summon', id: s0.id }, { type: 'weapon', id: w4.id }])
      party.replace_unseal_priority!([{ type: 'weapon', id: w3.id }])
      expect([w3.reload.unseal_priority, w4.reload.unseal_priority, s0.reload.unseal_priority]).to eq([1, nil, nil])
    end

    it 'rejects items from another party' do
      foreign = weapon_at(create(:party, :solomonis), 3)
      expect do
        party.replace_unseal_priority!([{ type: 'weapon', id: foreign.id }])
      end.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'rejects starting slots and repeats' do
      expect do
        party.replace_unseal_priority!([{ type: 'weapon', id: start_weapon.id }])
      end.to raise_error(ActiveRecord::RecordInvalid)
      expect do
        party.replace_unseal_priority!([{ type: 'weapon', id: w3.id }, { 'type' => 'weapon', 'id' => w3.id }])
      end.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'is only for Solomonis parties' do
      expect { create(:party).replace_unseal_priority!([]) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'rejects unsealed items' do
      unsealed = weapon_at(party, 6, seal_state: 'unsealed')
      expect do
        party.replace_unseal_priority!([{ type: 'weapon', id: unsealed.id }])
      end.to raise_error(ActiveRecord::RecordInvalid)
    end

    context 'with ranked lists' do
      let!(:s1) { summon_at(party, 1) }

      before do
        party.replace_unseal_priority!([{ type: 'weapon', id: w3.id }, { type: 'summon', id: s0.id },
                                        { type: 'weapon', id: w4.id }, { type: 'summon', id: s1.id }])
      end

      it 'renumbers only weapons when a ranked weapon is removed' do
        w3.reload.destroy!
        expect(w4.reload.unseal_priority).to eq(1)
        expect([s0.reload.unseal_priority, s1.reload.unseal_priority]).to eq([1, 2])
      end

      it 'renumbers only summons when a ranked summon is removed' do
        s0.reload.destroy!
        expect(s1.reload.unseal_priority).to eq(1)
        expect([w3.reload.unseal_priority, w4.reload.unseal_priority]).to eq([1, 2])
      end

      it 'renumbers only weapons when a ranked weapon is unsealed' do
        w3.reload.update!(seal_state: 'unsealed')
        expect(w3.unseal_priority).to be_nil
        expect(w4.reload.unseal_priority).to eq(1)
        expect([s0.reload.unseal_priority, s1.reload.unseal_priority]).to eq([1, 2])
      end

      it 'drops the priority of a weapon moved into a starting slot' do
        w3.reload.update!(position: 1)
        expect(w3.unseal_priority).to be_nil
        expect(w4.reload.unseal_priority).to eq(1)
        expect([s0.reload.unseal_priority, s1.reload.unseal_priority]).to eq([1, 2])
      end

      it 'renumbers each list on its own when recomputing' do
        GridWeapon.where(id: w4.id).update_all(unseal_priority: 5)
        GridSummon.where(id: s1.id).update_all(unseal_priority: 7)
        party.recompute_solomonis_state!
        expect([w3, w4, s0, s1].map { |row| row.reload.unseal_priority }).to eq([1, 2, 1, 2])
      end

      it 'drops position 2 from the list when Justice is added' do
        w2 = weapon_at(party.reload, 2)
        party.replace_unseal_priority!([{ type: 'weapon', id: w2.id }, { type: 'weapon', id: w3.id }])
        party.reload.replace_solomonis_blessings!([justice_level])
        expect(w2.reload.unseal_priority).to be_nil
        expect(w3.reload.unseal_priority).to eq(1)
      end
    end
  end
end
