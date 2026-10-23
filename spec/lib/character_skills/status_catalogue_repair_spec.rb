# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/migrate/20261021190000_repair_status_catalogue').to_s

RSpec.describe CharacterSkills::StatusCatalogueRepair do
  # Older catalogues hold duplicate names: lift name_key's constraints the way
  # bin/setup-pipeline-db does (rolled back with the example's transaction).
  before do
    allow(Granblue::Parsers::StatusName).to receive(:exceptions).and_return(Set['other self'])
    connection = ActiveRecord::Base.connection
    connection.remove_index :statuses, :name_key
    connection.remove_index :statuses, %i[name_en qualifier]
    connection.change_column_null :statuses, :name_key, true
  end

  def status(name, category, created_at)
    create(:status, name_en: name, category: category, created_at: created_at).tap { |s| s.update_columns(name_key: nil) }
  end

  it 'keeps the majority-category row per name, repoints effects and deletes the rest' do
    oldest_debuff = status('Charge Bar', 'debuff', 3.days.ago)
    buff = status('Charge Bar', 'buff', 2.days.ago)
    other_buff = status("charge\tbar ", 'buff', 1.day.ago)
    single = status('Veil', 'buff', 1.day.ago)
    effects = [oldest_debuff, buff, other_buff].map { |s| create(:skill_effect, status: s) }

    counts = described_class.call

    expect(counts).to include(merged_names: 1, deleted: 2, effects_repointed: 2)
    expect(Status.pluck(:id)).to contain_exactly(buff.id, single.id)
    expect(effects.map { |e| e.reload.status_id }).to all(eq(buff.id))
  end

  it 'lets a field row win over a buff majority' do
    status('Sun-Touched Paradise', 'buff', 3.days.ago)
    status('Sun-Touched Paradise', 'buff', 2.days.ago)
    field = status('Sun-touched Paradise', 'field', 1.day.ago)
    described_class.call
    expect(Status.pluck(:id)).to eq([field.id])
  end

  it 'merges names that differ only in non-ASCII case, as Ruby compares them' do
    status('ÄRGER UP', 'buff', 2.days.ago)
    status('Ärger Up', 'buff', 1.day.ago)
    described_class.call
    expect(Status.pluck(:name_key)).to eq(['ärger up'])
  end

  it 'derives family, level and name_key from the name, clearing stale values' do
    stale = status('ATK Down', 'debuff', 1.day.ago).tap { |s| s.update_columns(family: 'Blinded', level: 3) }
    described_class.call
    expect(stale.reload.attributes.slice('family', 'level', 'name_key'))
      .to eq('family' => nil, 'level' => nil, 'name_key' => 'atk down')
  end

  it 'merges numbered names into their status and moves the number to the effects' do
    plain = status('DEF Down', 'debuff', 3.days.ago)
    two = status('DEF Down 2', 'debuff', 2.days.ago)
    four = status("DEF Down\t4", 'buff', 1.day.ago)
    effects = [plain, two, four].map { |s| create(:skill_effect, status: s) }
    effects[1].update_columns(raw: '{{status|DEF Down 2|t=2T}}')

    counts = described_class.call

    expect(counts).to include(merged_names: 1, deleted: 2, variants_set: 2)
    expect(Status.pluck(:id, :name_en)).to eq([[plain.id, 'DEF Down']])
    expect(effects.map { |e| e.reload.attributes.values_at('status_id', 'status_variant') })
      .to eq([[plain.id, nil], [plain.id, 2], [plain.id, 4]])
    expect(effects.map { |e| e.reload.status_variant_kind }).to eq([nil, 'turns', nil])
  end

  it 'renames a lone numbered status to its plain name' do
    grovel = status('Grovel 1', 'debuff', 1.day.ago)
    effect = create(:skill_effect, status: grovel)
    described_class.call
    expect(grovel.reload.attributes.slice('name_en', 'name_key', 'level')).to eq('name_en' => 'Grovel', 'name_key' => 'grovel', 'level' => nil)
    expect(effect.reload.status_variant).to eq(1)
  end

  it 'keeps the number of an exception, as part of the name' do
    kept = status('Other Self 1', 'buff', 1.day.ago)
    status('Other Self', 'buff', 2.days.ago)
    described_class.call
    expect(kept.reload.attributes.slice('name_en', 'family', 'level')).to eq('name_en' => 'Other Self 1', 'family' => 'Other Self', 'level' => 1)
    expect(Status.count).to eq(2)
  end

  it 'merges an approved alias into its status and renames to the canonical spelling' do
    allow(Granblue::Parsers::StatusAliases).to receive(:map).and_return('blinded' => 'Blind', 'hostility boosted' => 'Hostility Up')
    blind = status('Blind', 'debuff', 2.days.ago)
    blinded = status('Blinded', 'debuff', 1.day.ago)
    effect = create(:skill_effect, status: blinded)
    hostility = status('Hostility Boosted', 'buff', 1.day.ago)

    described_class.call

    expect(Status.order(:name_en).pluck(:id, :name_en)).to eq([[blind.id, 'Blind'], [hostility.id, 'Hostility Up']])
    expect(effect.reload.status_id).to eq(blind.id)
  end

  it 'changes nothing on a repaired catalogue' do
    create(:status, name_en: 'Veil')
    expect(described_class.call).to eq(merged_names: 0, deleted: 0, effects_repointed: 0, variants_set: 0, renamed: 0,
                                       junk_deleted: 0, families_fixed: 0, keys_set: 0,
                                       display: { renamed: 0, qualified: [], review: [] })
  end

  describe 'shown names (D59)' do
    before do
      Granblue::Parsers::StatusList.use(<<~LUA)
        local buffs = { ['Jade Crest 1'] = { status = '14811' }, ['Mana 1'] = { status = '14871' } }
        local debuffs = { ['Drowsy'] = { status = '1263' }, ['Drowsy 1'] = { status = '1263_11' } }
        return { buffs = buffs, debuffs = debuffs, effects = {}, aliases = {} }
      LUA
    end

    it 'drops the trailing level number from the shown name, keeping the wiki name as the key' do
      crest = status('Jade Crest 1', 'buff', 1.day.ago)
      counts = described_class.call
      expect(crest.reload.attributes.slice('name_en', 'wiki_name', 'name_key', 'family', 'level', 'qualifier'))
        .to eq('name_en' => 'Jade Crest', 'wiki_name' => 'Jade Crest 1', 'name_key' => 'jade crest 1',
               'family' => 'Jade Crest', 'level' => 1, 'qualifier' => nil)
      expect(counts[:display]).to include(renamed: 1)
    end

    it 'tells apart two statuses that would show the same name with a qualifier, and keeps both' do
      plain = status('Drowsy', 'debuff', 2.days.ago)
      timed = status('Drowsy 1', 'debuff', 1.day.ago).tap { |s| s.update_columns(variant_kind: 'turns') }
      effects = [plain, timed].map { |s| create(:skill_effect, status: s) }

      2.times { described_class.call }

      expect(Status.order(:created_at).pluck(:id, :name_en, :qualifier)).to eq([[plain.id, 'Drowsy', nil], [timed.id, 'Drowsy', 'Turns']])
      expect(effects.map { |e| e.reload.status_id }).to eq([plain.id, timed.id])
      expect(described_class.call[:display]).to include(renamed: 0)
    end

    it "qualifies a status the wiki list doesn't have before a listed one" do
      unused = status('Mana', 'buff', 2.days.ago)
      used = status('Mana 1', 'buff', 1.day.ago)
      described_class.call
      expect([unused, used].map { |s| s.reload.qualifier }).to eq(['Unlisted', nil])
    end

    it 'deletes a status named like a template parameter, unlinking its effects' do
      junk = status('a=10%', 'debuff', 1.day.ago)
      effect = create(:skill_effect, status: junk)
      expect(described_class.call).to include(junk_deleted: 1)
      expect(Status.exists?(junk.id)).to be(false)
      expect(effect.reload.status_id).to be_nil
    end
  end

  it "is irreversible: the migration's down raises" do
    expect { RepairStatusCatalogue.new.down }.to raise_error(ActiveRecord::IrreversibleMigration)
  end
end
