# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GridDamage::ElementScope do
  describe '.scoped_skill?' do
    def version(text) = Struct.new(:description_en).new(text)

    it 'is true for skills that name the element they boost' do
      expect(described_class.scoped_skill?(version("Big boost to earth allies' ATK"))).to be(true)
      expect(described_class.scoped_skill?(version("Small boost to {{WeaponElement|wpn}} allies' ATK"))).to be(true)
      expect(described_class.scoped_skill?(version("Big boost to dark MC's ATK"))).to be(true)
      expect(described_class.scoped_skill?(version("25% boost to {{WeaponElement}} MC's {{atkmod|ATK|m=ex}}"))).to be(true)
    end

    it 'is false for skills that name no element' do
      expect(described_class.scoped_skill?(version("Boost to all allies' ATK based on number of Draphs"))).to be(false)
      expect(described_class.scoped_skill?(version('Boost to ATK based on how many axes are equipped'))).to be(false)
      expect(described_class.scoped_skill?(version(nil))).to be(false)
    end
  end

  describe '.panel_element' do
    let(:party) { create(:party) }

    it "is the main weapon's element, not the grid's majority" do
      create(:grid_weapon, party: party, position: -1, mainhand: true, weapon: create(:weapon, element: 2))
      2.times { |i| create(:grid_weapon, party: party, position: i, weapon: create(:weapon, element: 1)) }

      expect(described_class.panel_element(party.reload)).to eq('water')
    end
  end
end
