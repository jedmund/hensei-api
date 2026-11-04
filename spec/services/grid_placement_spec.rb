# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GridPlacement do
  let(:party) { create(:party) }

  describe '.move' do
    it 'moves a row to an empty slot and saves it' do
      row = create(:grid_summon, party: party, position: 0)
      move = described_class.move(row, 3)

      expect(move.saved).to be(true)
      expect(move.reordered).to be(false)
      expect(row.reload.position).to eq(3)
    end

    it 'refuses a slot outside the grid' do
      row = create(:grid_character, party: party, position: 0)

      expect { described_class.move(row, 8) }
        .to raise_error(described_class::InvalidPosition, 'Invalid position 8 for character')
      expect(row.reload.position).to eq(0)
    end

    it 'refuses an occupied slot' do
      row = create(:grid_weapon, party: party, position: 0)
      create(:grid_weapon, party: party, position: 1)

      expect { described_class.move(row, 1) }
        .to raise_error(described_class::PositionOccupied, 'Position 1 is already occupied')
    end

    it 'refuses the main and friend summon slots' do
      row = create(:grid_summon, party: party, position: 0)

      expect { described_class.move(row, -1) }
        .to raise_error(described_class::InvalidPosition, 'Cannot move summon to restricted position -1')
      expect { described_class.move(row, 6) }
        .to raise_error(described_class::InvalidPosition, 'Cannot move summon to restricted position 6')
    end

    it 'allows the mainhand for weapons' do
      row = create(:grid_weapon, party: party, position: 0, weapon: create(:weapon, element: 4))
      described_class.move(row, -1)

      expect(row.reload.position).to eq(-1)
      expect(party.reload.element).to eq(4)
    end

    it 'marks the party as extra when a weapon takes an extra slot' do
      row = create(:grid_weapon, party: party, position: 0, weapon: create(:weapon, extra: true))
      described_class.move(row, 11)

      expect(party.reload.extra).to be(true)
    end

    it 'reports a row that fails to save' do
      row = create(:grid_weapon, party: party, position: 0)
      allow(row).to receive(:save).and_return(false)
      move = described_class.move(row, 3)

      expect(move.saved).to be(false)
      expect(row.reload.position).to eq(0)
    end

    it 'compacts the main character slots when a character crosses into them' do
      main = create(:grid_character, party: party, position: 2)
      extra = create(:grid_character, party: party, position: 6)
      move = described_class.move(extra, 4)

      expect(move.reordered).to be(true)
      expect(main.reload.position).to eq(0)
      expect(extra.reload.position).to eq(1)
    end

    it 'leaves the main character slots alone for a move within them' do
      row = create(:grid_character, party: party, position: 1)
      move = described_class.move(row, 3)

      expect(move.reordered).to be(false)
      expect(row.reload.position).to eq(3)
    end
  end

  describe '.swap!' do
    it 'trades the slots of two rows' do
      first = create(:grid_weapon, party: party, position: 0)
      second = create(:grid_weapon, party: party, position: 5)
      described_class.swap!(first, second)

      expect(first.reload.position).to eq(5)
      expect(second.reload.position).to eq(0)
    end

    it 'refuses a summon in a restricted slot' do
      sub = create(:grid_summon, party: party, position: 0)
      main = create(:grid_summon, party: party, position: -1)

      expect { described_class.swap!(sub, main) }
        .to raise_error(described_class::InvalidPosition, 'Cannot swap summons in restricted positions')
      expect(main.reload.position).to eq(-1)
    end
  end

  describe '.claim_slot!' do
    it 'sets the party element for a weapon in the mainhand' do
      row = build(:grid_weapon, party: party, weapon: create(:weapon, element: 2))
      described_class.claim_slot!(row, -1)

      expect(party.reload.element).to eq(2)
    end

    it 'leaves the party alone for a regular slot' do
      row = build(:grid_weapon, party: party)

      expect { described_class.claim_slot!(row, 3) }.not_to(change { party.reload.attributes })
    end
  end
end
