# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Party, 'Evoking Solomonis', type: :model do
  let(:evoker) { create(:character, :solomonis_evoker, element: 5) }
  let(:zone) { evoker.solomonis_zone }

  def blessing_level(slug, cost: 50)
    blessing = create(:arcarum_blessing, slug.to_sym)
    create(:arcarum_blessing_level, arcarum_blessing: blessing, cost: cost)
  end

  describe 'route Evoker' do
    it "sets the party's raid and element from the route Evoker" do
      party = create(:party, :solomonis_build, route_evoker: evoker, element: 2)
      expect(party.raid).to eq(zone)
      expect(party.element).to eq(5)
      expect(party).to be_solomonis
      expect(party).to be_solomonis_build
    end

    it 'can be set through nested attributes' do
      party = create(:party)
      party.update!(solomonis_expedition_attributes: { kind: 'run', route_evoker_id: evoker.id })
      expect(party.reload.raid_id).to eq(zone.id)
      expect(party).to be_solomonis_run
    end

    it 'moves the party when the route changes' do
      party = create(:party, :solomonis_build, route_evoker: evoker)
      other = create(:character, :solomonis_evoker, element: 2)
      party.update!(solomonis_expedition_attributes: { route_evoker_id: other.id })
      expect(party.reload.raid_id).to eq(other.solomonis_zone_id)
      expect(party.element).to eq(2)
    end

    it 'rejects a different element' do
      party = create(:party, :solomonis_build, route_evoker: evoker)
      expect(party.update(element: 3)).to be(false)
      expect(party.errors[:element]).to be_present
    end

    it "rejects another Solomonis zone than the route Evoker's" do
      party = create(:party, :solomonis_build, route_evoker: evoker)
      other_zone = create(:raid, :solomonis_zone)
      expect(party.update(raid: other_zone)).to be(false)
      expect(party.errors[:raid]).to be_present
    end

    it 'requires an expedition in a Solomonis zone' do
      party = build(:party, raid: zone)
      expect(party).not_to be_valid
      expect(party.errors[:solomonis_expedition]).to be_present
    end

    it 'rejects an ineligible route Evoker' do
      party = create(:party)
      party.assign_solomonis_route(create(:character))
      expect(party).not_to be_valid
    end

    it "keeps the element when the mainhand's element differs" do
      party = create(:party, :solomonis_build, route_evoker: evoker)
      create(:grid_weapon, party: party, weapon: create(:weapon, element: 2), position: -1)
      party.reload.save!
      expect(party.reload.element).to eq(5)
    end
  end

  describe 'leaving the mode' do
    it 'deletes the Solomonis data when the raid moves out of the group' do
      party = create(:party, :solomonis_run, route_evoker: evoker)
      hanged_man = blessing_level(:hanged_man, cost: 60)
      party.replace_solomonis_blessings!([hanged_man])
      effect = create(:solomonis_guide_effect)
      party.replace_solomonis_guide_effects!([{ solomonis_guide_effect: effect, count: 1 }])
      weapon = create(:grid_weapon, party: party, position: 4, seal_state: 'unsealed')
      character = create(:grid_character, party: party, position: 0, brought_by_blessing: true)

      party.reload.update!(raid: create(:raid))

      expect(SolomonisExpedition.where(party_id: party.id)).to be_empty
      expect(PartyBlessing.where(party_id: party.id)).to be_empty
      expect(ExpeditionGuideEffect.where(party_id: party.id)).to be_empty
      expect(weapon.reload.seal_state).to be_nil
      expect(character.reload.brought_by_blessing).to be(false)
      expect(party.reload).not_to be_solomonis
    end
  end

  describe 'character limits' do
    it 'allows only the route Evoker on a build' do
      party = create(:party, :solomonis_build, route_evoker: evoker)
      create(:grid_character, party: party, character: evoker, position: 0)
      extra = build(:grid_character, party: party.reload, position: 1)
      expect(extra).not_to be_valid
    end

    it 'allows one more character with The Hanged Man' do
      party = create(:party, :solomonis_build, route_evoker: evoker)
      party.replace_solomonis_blessings!([blessing_level(:hanged_man, cost: 60)])
      create(:grid_character, party: party, character: evoker, position: 0)
      create(:grid_character, party: party.reload, position: 1)
      third = build(:grid_character, party: party.reload, position: 2)
      expect(third).not_to be_valid
    end

    it 'allows the route Evoker and 4 allies on a run' do
      party = create(:party, :solomonis_run, route_evoker: evoker)
      5.times { |i| create(:grid_character, party: party.reload, position: i) }
      sixth = build(:grid_character, party: party.reload, position: 5)
      expect(sixth).not_to be_valid
    end

    it 'rejects turning a full run into a build' do
      party = create(:party, :solomonis_run, route_evoker: evoker)
      2.times { |i| create(:grid_character, party: party.reload, position: i) }
      expect(party.reload.update(solomonis_expedition_attributes: { kind: 'build' })).to be(false)
      expect(party.errors[:characters]).to be_present
    end

    describe 'brought_by_blessing' do
      let(:party) { create(:party, :solomonis_run, route_evoker: evoker) }

      it 'needs The Hanged Man' do
        character = build(:grid_character, party: party, position: 0, brought_by_blessing: true)
        expect(character).not_to be_valid
      end

      it 'can be set on one character only' do
        party.replace_solomonis_blessings!([blessing_level(:hanged_man, cost: 60)])
        create(:grid_character, party: party.reload, position: 0, brought_by_blessing: true)
        second = build(:grid_character, party: party.reload, position: 1, brought_by_blessing: true)
        expect(second).not_to be_valid
      end

      it 'is not allowed outside Solomonis' do
        character = build(:grid_character, party: create(:party), position: 0, brought_by_blessing: true)
        expect(character).not_to be_valid
      end
    end
  end

  describe '#replace_solomonis_blessings!' do
    let(:party) { create(:party, :solomonis_build, route_evoker: evoker) }

    it 'replaces the loadout' do
      justice = blessing_level(:justice, cost: 50)
      party.replace_solomonis_blessings!([justice])
      death = create(:arcarum_blessing_level, cost: 20)
      party.replace_solomonis_blessings!([death])
      expect(party.reload.party_blessings.map(&:arcarum_blessing_level)).to eq([death])
    end

    it 'rejects a total cost over the limit' do
      levels = [create(:arcarum_blessing_level, cost: 70), create(:arcarum_blessing_level, cost: 40)]
      expect { party.replace_solomonis_blessings!(levels) }.to raise_error(ActiveRecord::RecordInvalid)
      expect(party.errors[:blessings].join).to include('limit')
      expect(party.party_blessings.reload).to be_empty
    end

    it 'accepts a total cost of exactly the limit' do
      levels = [create(:arcarum_blessing_level, cost: 70), create(:arcarum_blessing_level, cost: 30)]
      party.replace_solomonis_blessings!(levels)
      expect(party.solomonis_blessing_cost_total).to eq(100)
    end

    it 'rejects two levels of one blessing' do
      blessing = create(:arcarum_blessing)
      levels = [create(:arcarum_blessing_level, arcarum_blessing: blessing, cost: 10),
                create(:arcarum_blessing_level, arcarum_blessing: blessing, cost: 10)]
      expect { party.replace_solomonis_blessings!(levels) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'rejects unreleased blessings' do
      level = create(:arcarum_blessing_level, arcarum_blessing: create(:arcarum_blessing, :unreleased))
      expect { party.replace_solomonis_blessings!([level]) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'refuses to drop The Hanged Man while a build holds a second character' do
      party.replace_solomonis_blessings!([blessing_level(:hanged_man, cost: 60)])
      2.times { |i| create(:grid_character, party: party.reload, position: i) }
      expect { party.reload.replace_solomonis_blessings!([]) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "clears a run's brought_by_blessing when The Hanged Man is dropped" do
      run = create(:party, :solomonis_run, route_evoker: evoker)
      run.replace_solomonis_blessings!([blessing_level(:hanged_man, cost: 60)])
      character = create(:grid_character, party: run.reload, position: 0, brought_by_blessing: true)
      run.reload.replace_solomonis_blessings!([])
      expect(character.reload.brought_by_blessing).to be(false)
    end

    it 'is only for Solomonis parties' do
      expect { create(:party).replace_solomonis_blessings!([]) }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe '#replace_solomonis_guide_effects!' do
    let(:party) { create(:party, :solomonis_run, route_evoker: evoker) }
    let(:stackable) { create(:solomonis_guide_effect, stackable: true) }
    let(:unique) { create(:solomonis_guide_effect, :unique) }

    it 'replaces the guidebook' do
      party.replace_solomonis_guide_effects!([{ solomonis_guide_effect: stackable, count: 3 }])
      party.replace_solomonis_guide_effects!([{ solomonis_guide_effect_id: unique.id, count: 1, inherited: true }])
      expect(party.expedition_guide_effects.reload.map(&:solomonis_guide_effect)).to eq([unique])
    end

    it 'rejects two inherited effects' do
      entries = [{ solomonis_guide_effect: stackable, inherited: true },
                 { solomonis_guide_effect: unique, inherited: true }]
      expect { party.replace_solomonis_guide_effects!(entries) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'rejects a stack of a non-stackable effect' do
      expect do
        party.replace_solomonis_guide_effects!([{ solomonis_guide_effect: unique, count: 2 }])
      end.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'is only for runs' do
      build_party = create(:party, :solomonis_build, route_evoker: evoker)
      expect do
        build_party.replace_solomonis_guide_effects!([{ solomonis_guide_effect: stackable }])
      end.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe 'remix' do
    it 'copies the expedition and blessings but not the guidebook or run fields' do
      party = create(:party, :solomonis_run, route_evoker: evoker)
      party.solomonis_expedition.update!(outcome: 'cleared', bosses_defeated: 2, game_report_id: 7,
                                         pledge_level: 3, stats: { 'battle' => 1 })
      party.replace_solomonis_blessings!([blessing_level(:justice, cost: 50)])
      party.replace_solomonis_guide_effects!([{ solomonis_guide_effect: create(:solomonis_guide_effect) }])
      weapon = create(:grid_weapon, party: party.reload, position: 5, seal_state: 'unsealed')

      remix = party.reload.amoeba_dup
      remix.user = create(:user)
      remix.save!
      remix.reload

      expedition = remix.solomonis_expedition
      expect(expedition.kind).to eq('run')
      expect(expedition.route_evoker).to eq(evoker)
      expect(expedition.pledge_level).to eq(3)
      expect(expedition.outcome).to be_nil
      expect(expedition.game_report_id).to be_nil
      expect(expedition.stats).to eq({})
      expect(expedition.user_id).to eq(remix.user_id)
      expect(remix.party_blessings.map(&:slug)).to eq(['justice'])
      expect(remix.expedition_guide_effects).to be_empty
      expect(remix.weapons.find_by(position: weapon.position).seal_state).to eq('unsealed')
    end
  end
end
