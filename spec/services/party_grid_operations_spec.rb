# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PartyGridOperations do
  let(:party) { create(:party) }

  def batch(operations, **)
    described_class.new(party, operations, **)
  end

  describe '#initialize' do
    it 'needs an operations list' do
      expect { batch(nil) }.to raise_error(ArgumentError, 'operations are required')
    end
  end

  describe '#errors' do
    it 'is empty for well-formed operations' do
      operations = [
        { type: 'move', entity: 'weapon', id: 'a', position: 1 },
        { type: 'swap', entity: 'character', source_id: 'a', target_id: 'b' },
        { type: 'remove', entity: 'summon', id: 'a' }
      ]

      expect(batch(operations).errors).to eq([])
    end

    it 'names the missing fields, unknown types and bad entities by index' do
      operations = [
        { type: 'move', entity: 'weapon', position: 0 },
        { type: 'swap', entity: 'summon', source_id: 'a' },
        { type: 'jump', entity: 'job' }
      ]

      expect(batch(operations).errors).to eq([
                                               'Operation 0: missing id',
                                               'Operation 1: missing target_id',
                                               'Operation 2: unknown operation type jump',
                                               'Operation 2: invalid entity type job'
                                             ])
    end

    it 'counts a position of 0 as present' do
      expect(batch([{ type: 'move', entity: 'weapon', id: 'a', position: 0 }]).errors).to eq([])
    end
  end

  describe '#apply!' do
    describe 'move' do
      it 'moves a row to an empty slot and reports where from' do
        weapon = create(:grid_weapon, party: party, position: 0)

        changes = batch([{ type: 'move', entity: 'weapon', id: weapon.id, position: 2 }]).apply!

        expect(weapon.reload.position).to eq(2)
        expect(changes).to eq([{ entity: 'weapon', id: weapon.id, action: 'moved', from: 0, to: 2 }])
      end

      it 'refuses an occupied slot' do
        weapon = create(:grid_weapon, party: party, position: 0)
        create(:grid_weapon, party: party, position: 2)

        expect { batch([{ type: 'move', entity: 'weapon', id: weapon.id, position: 2 }]).apply! }
          .to raise_error(GridPlacement::PositionOccupied)
      end

      it "refuses a slot outside the entity's rules" do
        summon = create(:grid_summon, party: party, position: 1)

        expect { batch([{ type: 'move', entity: 'summon', id: summon.id, position: 6 }]).apply! }
          .to raise_error(GridPlacement::InvalidPosition)
        expect(summon.reload.position).to eq(1)
      end

      it "sets the party's element when a weapon takes the mainhand" do
        weapon = create(:grid_weapon, party: party, position: 0, weapon: create(:weapon, element: 3))

        batch([{ type: 'move', entity: 'weapon', id: weapon.id, position: -1 }]).apply!

        expect(party.reload.element).to eq(3)
      end

      it 'marks the party as using extra slots when a weapon takes one' do
        weapon = create(:grid_weapon, party: party, position: 0, weapon: create(:weapon, extra: true))

        batch([{ type: 'move', entity: 'weapon', id: weapon.id, position: 9 }]).apply!

        expect(party.reload.extra).to be(true)
      end

      it 'closes the gap a character leaves moving to an extra slot' do
        moving = create(:grid_character, party: party, position: 0)
        staying = create(:grid_character, party: party, position: 1)

        batch([{ type: 'move', entity: 'character', id: moving.id, position: 5 }]).apply!

        expect(moving.reload.position).to eq(5)
        expect(staying.reload.position).to eq(0)
      end

      it "doesn't find a row of another party" do
        foreign = create(:grid_weapon, party: create(:party), position: 0)

        expect { batch([{ type: 'move', entity: 'weapon', id: foreign.id, position: 2 }]).apply! }
          .to raise_error(ActiveRecord::RecordNotFound, "weapon #{foreign.id} not found")
        expect(foreign.reload.position).to eq(0)
      end
    end

    describe 'swap' do
      it 'trades two rows’ slots' do
        first = create(:grid_character, party: party, position: 0)
        second = create(:grid_character, party: party, position: 1)

        changes = batch([{ type: 'swap', entity: 'character', source_id: first.id, target_id: second.id }]).apply!

        expect([first.reload.position, second.reload.position]).to eq([1, 0])
        expect(changes).to eq([{ entity: 'character', id: first.id, action: 'swapped', with: second.id }])
      end

      it 'refuses the main and friend summon slots' do
        main = create(:grid_summon, party: party, position: -1, main: true)
        other = create(:grid_summon, party: party, position: 1)

        expect { batch([{ type: 'swap', entity: 'summon', source_id: main.id, target_id: other.id }]).apply! }
          .to raise_error(GridPlacement::InvalidPosition)
      end

      it 'skips a swap with a row missing' do
        row = create(:grid_character, party: party, position: 0)

        changes = batch([{ type: 'swap', entity: 'character', source_id: row.id, target_id: SecureRandom.uuid }]).apply!

        expect(changes).to eq([])
        expect(row.reload.position).to eq(0)
      end
    end

    describe 'remove' do
      it 'destroys the row' do
        summon = create(:grid_summon, party: party, position: 1)

        changes = batch([{ type: 'remove', entity: 'summon', id: summon.id }]).apply!

        expect(GridSummon.exists?(summon.id)).to be(false)
        expect(changes).to eq([{ entity: 'summon', id: summon.id, action: 'removed' }])
      end

      it 'skips a row that is missing or in another party' do
        foreign = create(:grid_summon, party: create(:party), position: 1)

        expect(batch([{ type: 'remove', entity: 'summon', id: foreign.id }]).apply!).to eq([])
        expect(GridSummon.exists?(foreign.id)).to be(true)
      end
    end

    it 'rolls every operation back when one fails' do
      weapon = create(:grid_weapon, party: party, position: 0)
      summon = create(:grid_summon, party: party, position: 1)

      expect do
        batch([
                { type: 'move', entity: 'weapon', id: weapon.id, position: 2 },
                { type: 'remove', entity: 'summon', id: summon.id },
                { type: 'move', entity: 'weapon', id: SecureRandom.uuid, position: 3 }
              ]).apply!
      end.to raise_error(ActiveRecord::RecordNotFound)

      expect(weapon.reload.position).to eq(0)
      expect(GridSummon.exists?(summon.id)).to be(true)
    end

    it 'compacts the main character slots afterwards when asked' do
      first = create(:grid_character, party: party, position: 1)
      second = create(:grid_character, party: party, position: 3)

      batch([], maintain_character_sequence: true).apply!

      expect([first.reload.position, second.reload.position]).to eq([0, 1])
    end
  end
end
