# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Parsers::StatusCatalogBuilder do
  let(:curated) { {} }

  before do
    allow(Granblue::Parsers::CuratedStatusCategories).to receive(:load).and_return(curated)
    allow(Granblue::Parsers::StatusName).to receive(:exceptions).and_return(Set.new)
  end

  def character(name, text, game: nil)
    Character.without_skill_build do
      create(:character, name_en: name, game_raw_en: game,
                         wiki_raw: "{{Character\n|abilitycount=1\n|a1_name=A\n|a1_effdesc=#{text}\n}}")
    end
  end

  def ability(ailment:, type:, details:)
    { 'ability' => { '1' => { 'ailment' => ailment, 'type' => type, 'ability_detail' => details } } }
  end

  def detail(category, *ids)
    { category => ids.map { |id| { 'status' => id, 'detail' => 'x' } } }
  end

  def category(name)
    Status.find_by(name_en: name)&.category
  end

  describe '.build_all' do
    it 'takes the category from how the texts use a name, over every character' do
      character('One', 'Gain {{status|Charge Bar}}.')
      character('Two', 'All allies gain {{status|Charge Bar}}.')
      character('Three', 'Gain {{status|Heal}}.<br />Inflict {{status|Charge Bar}}.')
      described_class.build_all
      expect(category('Charge Bar')).to eq('buff')
    end

    it "doesn't pair names with the game's ailment ids (Catherine: Charmed isn't Nightsmoke's id)" do
      game = ability(ailment: '6422001001,6422002001', type: 'enemy_special_skill_trigger_by_enemy,catherine_mark_b',
                     details: { 'debuff' => [{ 'status' => '6422', 'detail' => 'Locked on to by Nightsmoke' }] })
      character('Catherine', "Inflict {{status|Nightsmoke's Victim|t=2T}} on a foe. " \
                             "(Steal the foe's heart and land {{status|Charmed|t=180S}} when the foe uses a special attack.)",
                game: game)
      described_class.build_all
      expect(Status.where.not(game_ailment_id: nil)).to be_empty
      expect(category("Nightsmoke's Victim")).to eq('debuff')
      expect(category('Charmed')).to eq('debuff')
    end

    it "doesn't name a heal's ailment after the skill's status (Anila: the heal isn't Charge Bar)" do
      game = ability(ailment: '1041001001', type: 'heal', details: { 'buff' => [{ 'status' => '1041', 'detail' => 'Heal' }] })
      character('Anila', "Restore all allies' HP.<br />All allies gain {{status|Charge Bar|a=10%}}.", game: game)
      described_class.build_all
      expect(Status.pluck(:name_en, :game_ailment_id, :category)).to eq([['Charge Bar', nil, 'buff']])
    end

    it 'uses the curated category over the texts' do
      character('Caro', 'Gain {{status|Tuning}}.')
      allow(Granblue::Parsers::CuratedStatusCategories).to receive(:load).and_return('tuning' => { category: 'debuff', game_status_id: nil })
      described_class.build_all
      expect(category('Tuning')).to eq('debuff')
    end

    it "falls back to the game's single category, then to the name" do
      character('Gamer', 'Inflict {{status|Hitmark}} on a foe and gain {{status|Hitmark}}.',
                game: ability(ailment: '4002007001', type: 'x', details: { 'debuff' => [{ 'status' => '4002' }] }))
      character('Namer', "('''When {{status|Fire DEF Down}} is in effect:''' …)")
      described_class.build_all
      expect(category('Hitmark')).to eq('debuff')
      expect(category('Fire DEF Down')).to eq('debuff')
    end

    it 'reads field effects from the text, and the curated list wins over the text' do
      character('Alanaan', '({{status|Sun-Touched Paradise}} to the [[Field Effect|field]].)')
      character('Nier', 'Gain {{status|World of Death and Love}}.')
      allow(Granblue::Parsers::CuratedStatusCategories).to receive(:load)
        .and_return('world of death and love' => { category: 'field', game_status_id: nil })
      described_class.build_all
      expect([category('Sun-Touched Paradise'), category('World of Death and Love')]).to eq(%w[field field])
    end

    it 'merges spellings of one name into one status and keeps the existing row' do
      existing = Status.create!(name_en: 'Sun-touched Paradise', category: 'buff')
      character('Alanaan', 'Gain {{status|Sun-Touched Paradise}}.')
      described_class.build_all
      expect(Status.count).to eq(1)
      expect(existing.reload.name_en).to eq('Sun-touched Paradise')
    end

    it 'overwrites a stale category and recomputes family and level from the name' do
      stale = Status.create!(name_en: 'ATK Down', category: 'buff', family: 'Blinded', level: 3)
      character('One', 'Inflict {{status|ATK Down}} on a foe.')
      described_class.build_all
      expect(stale.reload.attributes.slice('category', 'family', 'level'))
        .to eq('category' => 'debuff', 'family' => nil, 'level' => nil)
    end

    it "links a name to the game's display id when a skill pairs them one to one" do
      character('One', 'Gain {{status|DEF Up}}.', game: ability(ailment: '1', type: 'x', details: detail('buff', '1019')))
      character('Two', 'Gain {{status|DEF Up}} and {{status|Veil}}.',
                game: ability(ailment: '1', type: 'x', details: detail('buff', '1019', '1003')))
      described_class.build_all
      expect(Status.order(:name_en).pluck(:name_en, :game_status_id)).to eq([['DEF Up', '1019'], %w[Veil 1003]])
    end

    it "takes the usual category from its effects: the game's array in one skill, the verbs in two others" do
      character('One', 'Gain {{status|Odd}}.', game: ability(ailment: '1', type: 'x', details: detail('buff', '7000')))
      character('Two', 'Inflict {{status|Odd}} on a foe. Inflict {{status|Odd}} on a foe.')
      described_class.build_all
      expect(Status.find_by(name_en: 'Odd').attributes.slice('game_status_id', 'category', 'mixed'))
        .to eq('game_status_id' => '7000', 'category' => 'debuff', 'mixed' => true)
    end

    it 'uses a curated display id, or none' do
      character('One', 'Gain {{status|Charge Boost}}.', game: ability(ailment: '1', type: 'x', details: detail('buff', '1476')))
      allow(Granblue::Parsers::CuratedStatusCategories).to receive(:load)
        .and_return('charge boost' => { category: nil, game_status_id: 'none' })
      described_class.build_all
      expect(Status.find_by(name_en: 'Charge Boost').game_status_id).to be_nil
    end

    it 'finds existing rows by key: tabs, newlines and non-ASCII case' do
      existing = [Status.create!(name_en: "DEF\tUp", category: 'buff'), Status.create!(name_en: 'ÄRGER UP', category: 'buff')]
      character('One', "Gain {{status|DEF Up}} and {{status|Ärger Up}}.")
      expect(described_class.build_all).to include(created: 0, failed: 0)
      expect(Status.pluck(:id)).to match_array(existing.map(&:id))
    end

    it "counts a status it can't save and goes on" do
      character('One', 'Gain {{status|Veil}} and {{status|Shield}}.')
      allow_any_instance_of(Status).to receive(:save!).and_wrap_original do |original, *args|
        raise ActiveRecord::RecordNotUnique, 'clash' if original.receiver.name_en == 'Shield'

        original.call(*args)
      end
      expect(described_class.build_all).to include(created: 1, failed: 1)
      expect(Status.pluck(:name_en)).to eq(['Veil'])
    end

    it 'warns about curated names no text mentions' do
      character('One', 'Gain {{status|Veil}}.')
      allow(Granblue::Parsers::CuratedStatusCategories).to receive(:load)
        .and_return('vail' => { category: 'buff', game_status_id: nil })
      allow(Rails.logger).to receive(:warn)
      described_class.build_all
      expect(Rails.logger).to have_received(:warn).with(/curated names no text mentions: vail/)
    end

    it 'makes one status of numbered names, with the base display id and the family kind' do
      character('One', 'Inflict {{status|DEF Down 2|t=2T}} on a foe.',
                game: ability(ailment: '1', type: 'x', details: detail('debuff', '1020_12')))
      character('Two', 'Inflict {{status|DEF Down 4|t=4T}} on a foe. Gain {{status|Deluge Crest 3}}.')
      described_class.build_all
      expect(Status.order(:name_en).pluck(:name_en, :game_status_id, :variant_kind))
        .to eq([['DEF Down', '1020', 'turns'], ['Deluge Crest', nil, 'level']])
    end

    it "takes status, id, description and wiki page from gbf.wiki's status list" do
      Granblue::Parsers::StatusList.use(File.read(Rails.root.join('spec/fixtures/wiki/status_list_extract.lua')))
      character('One', 'Inflict {{status|DEF Down 4|t=4T}} on a foe. Gain {{status|Other Self}}.')
      described_class.build_all
      expect(Status.order(:name_en).pluck(:name_en, :category, :game_status_id, :description, :wiki_slug))
        .to eq([['DEF Lowered', 'debuff', '1020', 'DEF is lowered', 'DEF_Down'],
                ['Dodge All', 'buff', '1019', 'Takes no DMG or debuffs while in effect', 'Dodge_All']])
    end

    it "prefers the game's array when the list says debuff and the game buff" do
      Granblue::Parsers::StatusList.use(<<~LUA)
        local debuffs = { ['Hostility Boosted'] = { page = 'Hostility', status = '1463', detail = 'More likely to be attacked' } }
        return { buffs = {}, debuffs = debuffs, effects = {}, aliases = {} }
      LUA
      character('One', 'Gain {{status|Hostility Boosted}}.', game: ability(ailment: '1', type: 'x', details: detail('buff', '1463')))
      described_class.build_all
      expect(Status.find_by(name_en: 'Hostility Boosted').category).to eq('buff')
    end

    it 'counts the game only in skills that name the status (a shared icon id belongs to both)' do
      Granblue::Parsers::StatusList.use(<<~LUA)
        local buffs = { ['Shared Buff'] = { status = '7000' }, ['Misfiled'] = { status = '7000' } }
        return { buffs = buffs, debuffs = {}, effects = {}, aliases = {} }
      LUA
      character('One', 'Gain {{status|Shared Buff}}.', game: ability(ailment: '1', type: 'x', details: detail('buff', '7000')))
      character('Two', 'Inflict {{status|Misfiled}} on a foe.', game: ability(ailment: '1', type: 'x', details: detail('debuff', '7000')))
      described_class.build_all
      expect(Status.order(:name_en).pluck(:name_en, :category)).to eq([%w[Misfiled debuff], ['Shared Buff', 'buff']])
    end

    it "takes the usual category from its effects, and marks a status whose effects split as mixed" do
      Granblue::Parsers::StatusList.use(<<~LUA)
        local debuffs = { ['Hostility Boosted'] = { status = '1463' } }
        return { buffs = {}, debuffs = debuffs, effects = {}, aliases = {} }
      LUA
      character('Seox', 'Gain {{status|Hostility Boosted}}.', game: ability(ailment: '1', type: 'x', details: detail('buff', '1463')))
      character('Grimnir', 'Gain {{status|Hostility Boosted}}.', game: ability(ailment: '1', type: 'x', details: detail('buff', '1463')))
      character('Clarisse', 'Self-inflict {{status|Hostility Boosted}}.',
                game: ability(ailment: '1', type: 'x', details: detail('debuff', '1463')))
      described_class.build_all
      expect(Status.find_by(name_en: 'Hostility Boosted').attributes.slice('category', 'mixed'))
        .to eq('category' => 'buff', 'mixed' => true)
    end

    it 'counts curated effects as the effects get them, so a curated status whose texts disagree is not mixed' do
      allow(Granblue::Parsers::CuratedStatusCategories).to receive(:load).and_return('bon vivant' => { category: 'buff', game_status_id: nil })
      character('Lamretta', 'Self-inflict {{status|Bon Vivant}}. Inflict {{status|Bon Vivant}} on a foe.')
      described_class.build_all
      expect(Status.find_by(name_en: 'Bon Vivant').attributes.slice('category', 'mixed')).to eq('category' => 'buff', 'mixed' => false)
    end

    it 'logs a failed catalogue repair and goes on building' do
      allow(CharacterSkills::StatusCatalogueRepair).to receive(:call).and_raise(ActiveRecord::StatementInvalid, 'boom')
      allow(Rails.logger).to receive(:error)
      character('One', 'Gain {{status|Veil}}.')
      expect(described_class.build_all).to include(created: 1)
      expect(Rails.logger).to have_received(:error).with(/repair failed/)
    end

    it 'merges rows the list ties together on the full build' do
      Granblue::Parsers::StatusList.use(File.read(Rails.root.join('spec/fixtures/wiki/status_list_extract.lua')))
      charm = Status.create!(name_en: 'Blind', category: 'debuff')
      effect = create(:skill_effect, status: charm)
      character('One', 'Inflict {{status|Blinded}} on a foe.')
      described_class.build_all
      expect(Status.pluck(:name_en)).to eq(['Blinded'])
      expect(effect.reload.status.name_en).to eq('Blinded')
    end

    it "refreshes a status no text mentions from the list" do
      Granblue::Parsers::StatusList.use(File.read(Rails.root.join('spec/fixtures/wiki/status_list_extract.lua')))
      orphan = Status.create!(name_en: 'Accuracy Lowered', category: 'buff')
      character('One', 'Gain {{status|Veil}}.')
      described_class.build_all
      expect(orphan.reload.attributes.slice('category', 'game_status_id')).to eq('category' => 'debuff', 'game_status_id' => '1032_4')
    end

    it 'gives the same catalogue when run twice' do
      character('One', 'Gain {{status|Veil}}.<br />Inflict {{status|Burned 2}} on a foe.',
                game: ability(ailment: '1', type: 'x', details: detail('buff', '1003')))
      character('Two', "('''While {{status|Veil}} is in effect:''' …)")
      described_class.build_all
      first = Status.order(:name_en).pluck(:id, :name_en, :category, :game_status_id, :family, :level, :updated_at)
      expect(described_class.build_all).to include(created: 0, updated: 0)
      expect(Status.order(:name_en).pluck(:id, :name_en, :category, :game_status_id, :family, :level, :updated_at)).to eq(first)
    end
  end

  describe '.build_for' do
    it 'adds the statuses the given characters name, and nothing else' do
      given = character('Given', 'Inflict {{status|Burned}} on a foe.')
      character('Other', 'Inflict {{status|Frozen}} on a foe.')
      result = described_class.build_for([given])
      expect(result).to include(created: 1)
      expect(Status.pluck(:name_en, :category)).to eq([%w[Burned debuff]])
    end

    it 'fills blank attributes but never overwrites the category build_all wrote' do
      status = Status.create!(name_en: 'Burned', category: 'buff', wiki_slug: nil)
      described_class.build_for([character('Given', 'Inflict {{status|Burned}} on a foe.')])
      expect(status.reload.category).to eq('buff')
      expect(status.wiki_slug).to eq('Burned')
    end
  end

  describe '.build_all with style data' do
    it "reads characters whose game data names its style" do
      put_source(character('Styled', 'Inflict {{status|Burned}} on a foe.'), :game_raw_en, { 'style' => 1 })
      described_class.build_all
      expect(Status.pluck(:name_en)).to eq(['Burned'])
    end
  end
end
