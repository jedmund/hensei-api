# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Evoking Solomonis seal state and unseal priority', type: :model do
  let(:evoker) { create(:character, :solomonis_evoker) }
  let(:build_party) { create(:party, :solomonis_build, route_evoker: evoker) }
  let(:run_party) { create(:party, :solomonis_run, route_evoker: evoker) }

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

  describe 'on a build' do
    it 'derives every state from position' do
      states = [-1, 0, 1, 2, 3, 8].to_h { |p| [p, weapon_at(build_party, p).seal_state] }
      expect(states).to eq(-1 => 'start', 0 => 'start', 1 => 'start', 2 => 'sealed', 3 => 'sealed', 8 => 'sealed')
    end

    it 'starts the main summon only' do
      expect(summon_at(build_party, -1).seal_state).to eq('start')
      expect(summon_at(build_party, 0).seal_state).to eq('sealed')
      expect(summon_at(build_party, 4).seal_state).to eq('sealed')
    end

    it 'rejects a seal state from the client' do
      weapon = weapon_at(build_party, 3)
      expect(weapon.update(seal_state: 'unsealed')).to be(false)
      expect(weapon.update(seal_state: 'start')).to be(false)
    end

    it 'starts position 2 with Justice and seals it again without' do
      weapon = weapon_at(build_party, 2)
      build_party.replace_solomonis_blessings!([justice_level])
      expect(weapon.reload.seal_state).to eq('start')
      expect(weapon_at(build_party.reload, 2).seal_state).to eq('start')
      build_party.reload.replace_solomonis_blessings!([])
      expect(weapon.reload.seal_state).to eq('sealed')
    end

    it 're-derives the state when a weapon moves' do
      weapon = weapon_at(build_party, 0)
      weapon.update!(position: 5)
      expect(weapon.seal_state).to eq('sealed')
      weapon.update!(position: 1)
      expect(weapon.seal_state).to eq('start')
    end
  end

  describe 'on a run' do
    it 'starts the fixed slots and leaves the rest unknown' do
      expect(weapon_at(run_party, 0).seal_state).to eq('start')
      expect(weapon_at(run_party, 4).seal_state).to be_nil
      expect(summon_at(run_party, 1).seal_state).to be_nil
    end

    it 'records unsealed or sealed on other slots' do
      weapon = weapon_at(run_party, 4)
      expect(weapon.update(seal_state: 'unsealed')).to be(true)
      expect(weapon.update(seal_state: 'sealed')).to be(true)
      expect(weapon.update(seal_state: nil)).to be(true)
    end

    it 'rejects start outside a starting slot and anything else on one' do
      expect(weapon_at(run_party, 4).update(seal_state: 'start')).to be(false)
      expect(weapon_at(run_party, 0).update(seal_state: 'sealed')).to be(false)
    end

    it 'turns position 2 back to unknown when Justice is removed' do
      run_party.replace_solomonis_blessings!([justice_level])
      weapon = weapon_at(run_party.reload, 2)
      expect(weapon.seal_state).to eq('start')
      run_party.reload.replace_solomonis_blessings!([])
      expect(weapon.reload.seal_state).to be_nil
    end

    it 'rejects unseal priority' do
      weapon = weapon_at(run_party, 4, seal_state: 'sealed')
      expect(weapon.update(unseal_priority: 1)).to be(false)
    end
  end

  it 'rejects a support summon on a Solomonis party' do
    summon = build(:grid_summon, party: build_party, summon: create(:summon), position: 6, friend: true)
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
    party.reload.update!(solomonis_expedition_attributes: { kind: 'build', route_evoker_id: evoker.id })
    expect(weapon.reload.seal_state).to eq('sealed')
    expect(summon.reload.seal_state).to eq('start')
  end

  it 'clears unknowns and priorities when a build becomes a run, and derives them back' do
    weapon = weapon_at(build_party, 4)
    build_party.replace_unseal_priority!([{ type: 'weapon', id: weapon.id }])
    build_party.reload.update!(solomonis_expedition_attributes: { kind: 'run' })
    expect(weapon.reload.unseal_priority).to be_nil
    expect(weapon.seal_state).to eq('sealed')
  end

  describe '#replace_unseal_priority!' do
    let!(:w3) { weapon_at(build_party, 3) }
    let!(:w4) { weapon_at(build_party, 4) }
    let!(:s0) { summon_at(build_party, 0) }
    let!(:start_weapon) { weapon_at(build_party, 0) }

    it 'numbers one list across weapons and summons' do
      build_party.replace_unseal_priority!([{ type: 'summon', id: s0.id }, { type: 'weapon', id: w4.id }])
      expect([s0.reload.unseal_priority, w4.reload.unseal_priority, w3.reload.unseal_priority]).to eq([1, 2, nil])
    end

    it 'rejects items from another party' do
      foreign = weapon_at(create(:party, :solomonis_build), 3)
      expect do
        build_party.replace_unseal_priority!([{ type: 'weapon', id: foreign.id }])
      end.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'rejects starting slots and repeats' do
      expect do
        build_party.replace_unseal_priority!([{ type: 'weapon', id: start_weapon.id }])
      end.to raise_error(ActiveRecord::RecordInvalid)
      expect do
        build_party.replace_unseal_priority!([{ type: 'weapon', id: w3.id }, { 'type' => 'weapon', 'id' => w3.id }])
      end.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'is only for builds' do
      expect { run_party.replace_unseal_priority!([]) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    context 'with a ranked list' do
      before do
        build_party.replace_unseal_priority!([{ type: 'weapon', id: w3.id }, { type: 'summon', id: s0.id },
                                              { type: 'weapon', id: w4.id }])
      end

      it 'closes the gap when a ranked item is removed' do
        s0.reload.destroy!
        expect([w3.reload.unseal_priority, w4.reload.unseal_priority]).to eq([1, 2])
      end

      it 'drops the priority of a weapon moved into a starting slot' do
        w3.reload.update!(position: 1)
        expect(w3.unseal_priority).to be_nil
        expect([s0.reload.unseal_priority, w4.reload.unseal_priority]).to eq([1, 2])
      end

      it 'drops position 2 from the list when Justice is added' do
        w2 = weapon_at(build_party.reload, 2)
        build_party.replace_unseal_priority!([{ type: 'weapon', id: w2.id }, { type: 'weapon', id: w3.id }])
        build_party.reload.replace_solomonis_blessings!([justice_level])
        expect(w2.reload.unseal_priority).to be_nil
        expect(w3.reload.unseal_priority).to eq(1)
      end
    end
  end
end
