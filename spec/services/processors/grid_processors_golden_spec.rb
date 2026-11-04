# frozen_string_literal: true

require 'rails_helper'

# Pins what the character, summon and weapon processors build from real game
# decks: every grid item's attributes and the collection copies they link to or
# create. The goldens hold catalogue ids (granblue_id, slugs), never row ids.
#
# Regenerate with WRITE_GOLDENS=1 only for an intended change, and review the diff.
RSpec.describe 'Grid processors on real decks' do
  let(:golden_dir) { Rails.root.join('spec/fixtures/deck_import') }
  let(:user) { create(:user) }
  let(:party) { create(:party, user: user) }

  def run_processors(deck, target = party)
    [Processors::CharacterProcessor, Processors::SummonProcessor, Processors::WeaponProcessor].flat_map do |klass|
      processor = klass.new(target, deck)
      processor.process
      processor.warnings
    end
  end

  def character_rows(target)
    GridCharacter.where(party: target).includes(:character, :awakening, :collection_character).order(:position).map do |gc|
      { position: gc.position, granblue_id: gc.character.granblue_id, uncap_level: gc.uncap_level,
        transcendence_step: gc.transcendence_step, perpetuity: gc.perpetuity,
        awakening: gc.awakening&.slug, awakening_level: gc.awakening_level,
        collection: gc.collection_character && collection_character_row(gc.collection_character) }
    end
  end

  def collection_character_row(cc)
    { granblue_id: cc.character.granblue_id, uncap_level: cc.uncap_level, transcendence_step: cc.transcendence_step,
      perpetuity: cc.perpetuity, awakening: cc.awakening&.slug, awakening_level: cc.awakening_level }
  end

  def summon_rows(target)
    GridSummon.where(party: target).includes(:summon, :collection_summon).order(:position).map do |gs|
      { position: gs.position, granblue_id: gs.summon.granblue_id, main: gs.main, friend: gs.friend,
        quick_summon: gs.quick_summon, uncap_level: gs.uncap_level, transcendence_step: gs.transcendence_step,
        collection: gs.collection_summon && { game_id: gs.collection_summon.game_id,
                                              uncap_level: gs.collection_summon.uncap_level,
                                              transcendence_step: gs.collection_summon.transcendence_step } }
    end
  end

  def weapon_rows(target)
    GridWeapon.where(party: target).includes(:weapon, :collection_weapon).order(:position).map do |gw|
      { position: gw.position, granblue_id: gw.weapon.granblue_id, mainhand: gw.mainhand,
        uncap_level: gw.uncap_level, transcendence_step: gw.transcendence_step, element: gw.element,
        awakening: gw.awakening&.slug, awakening_level: gw.awakening_level,
        keys: [gw.weapon_key1, gw.weapon_key2, gw.weapon_key3].map { |key| key&.slug },
        ax: [gw.ax_modifier1&.slug, gw.ax_strength1, gw.ax_modifier2&.slug, gw.ax_strength2],
        collection: gw.collection_weapon && collection_weapon_row(gw.collection_weapon) }
    end
  end

  def collection_weapon_row(copy)
    { game_id: copy.game_id, uncap_level: copy.uncap_level, transcendence_step: copy.transcendence_step,
      element: copy.element, keys: [copy.weapon_key1, copy.weapon_key2, copy.weapon_key3].map { |key| key&.slug },
      awakening: copy.awakening&.slug, awakening_level: copy.awakening_level }
  end

  def snapshot(warnings, target = party)
    JSON.parse({
      characters: character_rows(target), summons: summon_rows(target), weapons: weapon_rows(target),
      warnings: warnings,
      counts: { collection_characters: user.collection_characters.count,
                collection_summons: user.collection_summons.count,
                collection_weapons: user.collection_weapons.count }
    }.to_json)
  end

  def expect_golden(name, actual)
    path = golden_dir.join("#{name}.json")
    if ENV['WRITE_GOLDENS']
      FileUtils.mkdir_p(golden_dir)
      File.write(path, "#{JSON.pretty_generate(actual)}\n")
    end
    expect(actual).to eq(JSON.parse(path.read))
  end

  %w[deck_sample deck_sample2].each do |fixture|
    context "with #{fixture}.json" do
      let(:deck) { JSON.parse(Rails.root.join("spec/fixtures/#{fixture}.json").read) }

      it 'builds the grid and creates the collection copies' do
        expect_golden("#{fixture}_import", snapshot(run_processors(deck)))
      end

      it 'builds the same grid without collection copies when the user does not import them' do
        user.update!(import_weapons: false)
        expect_golden("#{fixture}_no_collection", snapshot(run_processors(deck)))
      end

      it 'links to collection copies the user already has, raising their uncap from the game' do
        run_processors(deck)
        user.collection_summons.update_all(uncap_level: 0, transcendence_step: 0)
        user.collection_weapons.update_all(uncap_level: 0, transcendence_step: 0)
        user.collection_characters.update_all(uncap_level: 0, transcendence_step: 0)
        second = create(:party, user: user)

        expect_golden("#{fixture}_existing_collection", snapshot(run_processors(deck, second), second))
      end
    end
  end

  context 'with a summon the grid rejects' do
    let(:deck) { JSON.parse(Rails.root.join('spec/fixtures/deck_sample.json').read) }

    it 'reports it as skipped and keeps the others' do
      allow_any_instance_of(GridSummon).to receive(:save!).and_wrap_original do |original, *args| # rubocop:disable RSpec/AnyInstance -- the processor builds the record itself
        record = original.receiver
        raise ActiveRecord::RecordInvalid, record if record.position == 1 && record.errors.add(:base, 'nope')

        original.call(*args)
      end

      warnings = Processors::SummonProcessor.new(party, deck).tap(&:process).warnings
      expect(warnings).to eq([{ code: 'item_skipped', type: 'summon', position: 1, granblue_id: '2040425000',
                                name: Summon.find_by(granblue_id: '2040425000').name_en, details: ['nope'] }])
      expect(GridSummon.where(party: party).pluck(:position)).not_to include(1)
      expect(party.summons.target).to all(be_persisted)
    end
  end

  context 'with a character the grid rejects' do
    let(:deck) { JSON.parse(Rails.root.join('spec/fixtures/deck_sample2.json').read) }

    it 'skips it without a warning' do
      allow_any_instance_of(GridCharacter).to receive(:save!).and_wrap_original do |original, *args| # rubocop:disable RSpec/AnyInstance -- the processor builds the record itself
        record = original.receiver
        raise ActiveRecord::RecordInvalid, record if record.position == 2 && record.errors.add(:base, 'nope')

        original.call(*args)
      end

      processor = Processors::CharacterProcessor.new(party, deck).tap(&:process)
      expect(processor.warnings).to eq([])
      expect(GridCharacter.where(party: party).pluck(:position)).to contain_exactly(0, 1, 3, 4)
    end
  end
end
