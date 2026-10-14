# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Party, 'Evoking Solomonis', type: :model do
  let(:evoker) { create(:character, :solomonis_evoker, element: 5) }
  let(:zone) { evoker.solomonis_zone }

  def blessing_level(slug, cost: 50)
    blessing = create(:arcarum_blessing, slug.to_sym)
    create(:arcarum_blessing_level, arcarum_blessing: blessing, cost: cost)
  end

  def queries_during(&)
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] }
    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record', &)
    queries
  end

  def party_lock?(sql)
    sql.match?(/FROM "parties".*FOR UPDATE/m)
  end

  describe 'route Evoker' do
    it "sets the party's raid and element from the route Evoker" do
      party = create(:party, :solomonis, route_evoker: evoker, element: 2)
      expect(party.raid).to eq(zone)
      expect(party.element).to eq(5)
      expect(party).to be_solomonis
    end

    it 'can be set through nested attributes' do
      party = create(:party)
      party.update!(solomonis_expedition_attributes: { route_evoker_id: evoker.id })
      expect(party.reload.raid_id).to eq(zone.id)
      expect(party).to be_solomonis
    end

    it 'moves the party when the route changes' do
      party = create(:party, :solomonis, route_evoker: evoker)
      other = create(:character, :solomonis_evoker, element: 2)
      party.update!(solomonis_expedition_attributes: { route_evoker_id: other.id })
      expect(party.reload.raid_id).to eq(other.solomonis_zone_id)
      expect(party.element).to eq(2)
    end

    it 'rejects a different element' do
      party = create(:party, :solomonis, route_evoker: evoker)
      expect(party.update(element: 3)).to be(false)
      expect(party.errors[:element]).to be_present
    end

    it "rejects another Solomonis zone than the route Evoker's" do
      party = create(:party, :solomonis, route_evoker: evoker)
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
      party = create(:party, :solomonis, route_evoker: evoker)
      create(:grid_weapon, party: party, weapon: create(:weapon, element: 2), position: -1)
      party.reload.save!
      expect(party.reload.element).to eq(5)
    end
  end

  describe 'leaving the mode' do
    it 'deletes the Solomonis data when the raid moves out of the group' do
      party = create(:party, :solomonis, route_evoker: evoker)
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
    it 'allows the route Evoker and 4 allies' do
      party = create(:party, :solomonis, route_evoker: evoker)
      5.times { |i| create(:grid_character, party: party.reload, position: i) }
      sixth = build(:grid_character, party: party.reload, position: 5)
      expect(sixth).not_to be_valid
    end

    it "counts The Hanged Man's ally among the 4" do
      party = create(:party, :solomonis, route_evoker: evoker)
      party.replace_solomonis_blessings!([blessing_level(:hanged_man, cost: 60)])
      4.times { |i| create(:grid_character, party: party.reload, position: i) }
      create(:grid_character, party: party.reload, position: 4, brought_by_blessing: true)
      sixth = build(:grid_character, party: party.reload, position: 5)
      expect(sixth).not_to be_valid
    end

    it 'rejects entering the mode with more than 5 characters' do
      party = create(:party)
      6.times { |i| create(:grid_character, party: party.reload, position: i) }
      expect(party.reload.update(solomonis_expedition_attributes: { route_evoker_id: evoker.id })).to be(false)
      expect(party.errors[:characters]).to be_present
    end

    describe 'brought_by_blessing' do
      let(:party) { create(:party, :solomonis, route_evoker: evoker) }

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
    let(:party) { create(:party, :solomonis, route_evoker: evoker) }

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

    it 'clears brought_by_blessing when The Hanged Man is dropped' do
      party.replace_solomonis_blessings!([blessing_level(:hanged_man, cost: 60)])
      2.times { |i| create(:grid_character, party: party.reload, position: i) }
      character = create(:grid_character, party: party.reload, position: 2, brought_by_blessing: true)
      party.reload.replace_solomonis_blessings!([])
      expect(character.reload.brought_by_blessing).to be(false)
      expect(party.characters.reload.size).to eq(3)
    end

    it 'is only for Solomonis parties' do
      expect { create(:party).replace_solomonis_blessings!([]) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'locks the party before replacing the loadout' do
      queries = queries_during { party.replace_solomonis_blessings!([blessing_level(:justice)]) }
      lock = queries.index { |sql| party_lock?(sql) }
      expect(lock).to be < queries.index { |sql| sql.start_with?('DELETE FROM "party_blessings"') }
    end

    it 'locks the party even when the loadout is rejected' do
      levels = [create(:arcarum_blessing_level, cost: 70), create(:arcarum_blessing_level, cost: 40)]
      queries = queries_during do
        expect { party.replace_solomonis_blessings!(levels) }.to raise_error(ActiveRecord::RecordInvalid)
      end
      expect(queries).to include(satisfy { |sql| party_lock?(sql) })
    end
  end

  describe '#replace_solomonis_guide_effects!' do
    let(:party) { create(:party, :solomonis, route_evoker: evoker) }
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

    it 'is only for Solomonis parties' do
      expect do
        create(:party).replace_solomonis_guide_effects!([{ solomonis_guide_effect: stackable }])
      end.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'locks the party before replacing the guidebook' do
      queries = queries_during { party.replace_solomonis_guide_effects!([{ solomonis_guide_effect: stackable }]) }
      lock = queries.index { |sql| party_lock?(sql) }
      expect(lock).to be < queries.index { |sql| sql.start_with?('DELETE FROM "expedition_guide_effects"') }
    end
  end

  describe 'remix' do
    it 'copies the expedition, blessings, seals and unseal priority but not the guidebook or results' do
      party = create(:party, :solomonis, route_evoker: evoker)
      party.solomonis_expedition.update!(outcome: 'cleared', game_report_id: 7, ended_at: Time.current,
                                         pledge_level: 3, stats: { 'battle' => 1 })
      party.replace_solomonis_blessings!([blessing_level(:justice, cost: 50)])
      party.replace_solomonis_guide_effects!([{ solomonis_guide_effect: create(:solomonis_guide_effect) }])
      weapon = create(:grid_weapon, party: party.reload, position: 5, seal_state: 'unsealed')
      sealed = [6, 7].map { |p| create(:grid_weapon, party: party.reload, position: p) }
      summon = create(:grid_summon, party: party.reload, position: 1)
      party.replace_unseal_priority!([{ type: 'weapon', id: sealed[1].id }, { type: 'summon', id: summon.id },
                                      { type: 'weapon', id: sealed[0].id }])

      remix = party.reload.amoeba_dup
      remix.user = create(:user)
      remix.save!
      remix.reload

      expedition = remix.solomonis_expedition
      expect(expedition.route_evoker).to eq(evoker)
      expect(expedition.pledge_level).to eq(3)
      expect(expedition.outcome).to be_nil
      expect(expedition.game_report_id).to be_nil
      expect(expedition.ended_at).to be_nil
      expect(expedition.stats).to eq({})
      expect(expedition.user_id).to eq(remix.user_id)
      expect(remix.party_blessings.map(&:slug)).to eq(['justice'])
      expect(remix.expedition_guide_effects).to be_empty
      expect(remix.weapons.find_by(position: weapon.position).seal_state).to eq('unsealed')
      expect(remix.weapons.where(position: [6, 7]).order(:position).pluck(:seal_state, :unseal_priority))
        .to eq([['sealed', 2], ['sealed', 1]])
      expect(remix.summons.find_by(position: 1).slice(:seal_state, :unseal_priority))
        .to eq('seal_state' => 'sealed', 'unseal_priority' => 1)
    end
  end
end
