# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/data/20261024120000_renumber_enums_to_game_ids')

RSpec.describe RenumberEnumsToGameIds do
  subject(:migration) { described_class.new }

  # Rows are written the way the old numbering stored them: update_columns skips validations
  # and callbacks, so the factories' new-numbered defaults don't matter.
  def stored(record, **columns)
    record.update_columns(**columns)
    record
  end

  # Old support summon sections aren't all valid enum values any more (Misc was 7).
  def stored_section(record, section)
    record.class.where(id: record.id).update_all("section = #{section}")
    record
  end

  # Old numbering: 1 Wind, 2 Fire, 3 Water, 4 Earth, 5 Dark, 6 Light;
  # 3 Axe, 4 Spear, 5 Bow, 6 Staff, 8 Harp, 9 Gun; 0 Unknown, 5 Primal, 6 None.
  let!(:fediel) do
    stored(Character.without_skill_build { create(:character) },
           element: 5, proficiency1: 1, proficiency2: 7, race1: 3, race2: nil)
  end
  let!(:helel) do
    stored(Character.without_skill_build { create(:character) },
           element: 6, proficiency1: 9, proficiency2: 8, race1: 6, race2: 6)
  end
  let!(:nehan) { stored(Character.without_skill_build { create(:character) }, element: 1, race1: 2, race2: 0) }
  let!(:lich) { stored(Character.without_skill_build { create(:character) }, element: 3, race1: 5, race2: nil) }

  let!(:weapon) do
    stored(create(:weapon), element: 0, proficiency: 4,
                            element_variant_ids: { '1' => 'w300', '2' => 'w000', '6' => 'w400' })
  end

  let(:crew) { create(:crew) }
  let!(:wind_roster) { stored(create(:crew_roster, crew: crew, element: 1), element: 1) }
  let!(:earth_roster) { stored(create(:crew_roster, crew: crew, element: 3), element: 4) }

  let(:summoner) { create(:user) }
  let!(:wind_slot) { stored_section(create(:support_summon, user: summoner, section: :fire, position: 0), 1) }
  let!(:earth_slot) { stored_section(create(:support_summon, user: summoner, section: :earth, position: 0), 4) }
  let!(:misc_slot) { stored_section(create(:support_summon, user: summoner, section: :misc, position: 0), 7) }

  let!(:races_effect) do
    WeaponSkillEffect.create!(modifier: 'Spec Races', boost_type: 'atk', scaling_kind: 'flat',
                              condition: { 'races' => [1, 5, 0] })
  end
  let!(:specialty_target) { create(:solomonis_guide_effect, target_type: 'proficiency', target_values: [9, 3, 5]) }
  let!(:race_target) { create(:solomonis_guide_effect, target_type: 'race', target_values: [5, 6]) }

  let(:mention) do
    { 'type' => 'mention', 'attrs' => { 'id' => {
      'type' => 'character', 'granblue_id' => '3040376000', 'proficiency' => [1, 9],
      'element' => { 'id' => 5, 'weaknessId' => 6, 'slug' => 'dark' }
    } } }
  end
  let!(:party) do
    stored(create(:party), element: 2,
                           description: { 'type' => 'doc', 'content' => [{ 'type' => 'paragraph', 'content' => [mention] }] }.to_json)
  end

  around { |example| ActiveRecord::Migration.suppress_messages { example.run } }

  it "moves every column to the game's numbers" do
    migration.up

    expect(fediel.reload).to have_attributes(element: 6, proficiency1: 1, proficiency2: 7, race1: 3, race2: nil)
    expect(lich.reload).to have_attributes(element: 2, race1: 6)
    expect(weapon.reload).to have_attributes(element: 0, proficiency: 3)
    expect(weapon.element_variant_ids).to eq('4' => 'w300', '1' => 'w000', '5' => 'w400')
    expect(party.reload.element).to eq(1)
  end

  it 'folds None and Unknown into Other and clears race2 values that are not a second race' do
    migration.up

    expect(helel.reload).to have_attributes(element: 5, proficiency1: 6, proficiency2: 9, race1: 5, race2: nil)
    expect(nehan.reload).to have_attributes(element: 4, race1: 2, race2: nil)
  end

  it 'swaps values inside unique indexes, with Misc moving to 0' do
    migration.up

    expect(wind_roster.reload.element).to eq(4)
    expect(earth_roster.reload.element).to eq(3)
    expect([wind_slot, earth_slot, misc_slot].map { |s| s.reload.section }).to eq(%w[wind earth misc])
    expect(misc_slot.read_attribute_before_type_cast(:section)).to eq(0)
  end

  it "renumbers weapon-skill race lists and Solomonis proficiency targets, but not race targets" do
    migration.up

    expect(races_effect.reload.condition).to eq('races' => [1, 6, 5])
    expect(specialty_target.reload.target_values).to eq([6, 4, 8])
    expect(race_target.reload.target_values).to eq([5, 6])
  end

  it 'skips tables the database never created' do
    ActiveRecord::Base.connection.drop_table(:events, force: :cascade)

    expect { migration.up }.not_to raise_error
    expect(fediel.reload.element).to eq(6)
  end

  it 'renumbers rich-text mention tokens' do
    migration.up

    token = JSON.parse(party.reload.description).dig('content', 0, 'content', 0, 'attrs', 'id')
    expect(token['element']).to include('id' => 6, 'weaknessId' => 5, 'slug' => 'dark')
    expect(token['proficiency']).to eq([1, 6])
  end

  it 'reverses everything except the race clean-up' do
    migration.up
    migration.down

    expect(fediel.reload).to have_attributes(element: 5, proficiency1: 1, proficiency2: 7, race1: 3)
    expect(lich.reload).to have_attributes(element: 3, race1: 5)
    expect(helel.reload).to have_attributes(element: 6, proficiency1: 9, race1: 0, race2: nil)
    expect(weapon.reload.element_variant_ids).to eq('1' => 'w300', '2' => 'w000', '6' => 'w400')
    expect(earth_roster.reload.element).to eq(4)
    expect(SupportSummon.connection.select_value("SELECT section FROM support_summons WHERE id = '#{misc_slot.id}'")).to eq(7)
    expect(specialty_target.reload.target_values).to eq([9, 3, 5])
    expect(JSON.parse(party.reload.description).dig('content', 0, 'content', 0, 'attrs', 'id', 'proficiency')).to eq([1, 9])
  end
end
