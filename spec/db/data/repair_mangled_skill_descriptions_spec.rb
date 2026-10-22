# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'RepairMangledSkillDescriptions' do
  let(:migration_class) do
    unless defined?(RepairMangledSkillDescriptions)
      require Rails.root.join('db/data/20261016170101_repair_mangled_skill_descriptions')
    end
    RepairMangledSkillDescriptions
  end

  let(:weapon) { create(:weapon, wiki_en: 'Dread Scythe') }
  let(:page) do
    <<~WIKI
      {{Weapon
      |s1_name=Dreadflame's Claws
      |s1_desc='''When main weapon (MC only):''' 20% Bonus DMG against foes with {{status|Burned}}.
      |s2_name=Hoarfrost's Heed
      |s2_desc=Small boost to DA rate / Slight chance to dodge (Big DMG)|s3_name=Tsunami's Might
      }}
    WIKI
  end

  def version_with(name, text, position:)
    slot = create(:weapon_skill, weapon: weapon, position: position)
    skill = create(:skill, name_en: name, description_en: text)
    create(:weapon_skill_version, weapon_skill: slot, skill: skill, ordinal: 0, description_en: text)
  end

  def migrate
    migration_class.new.tap { |m| m.verbose = false }.up
  end

  # weapon_sources, the table this migration read (WeaponSource reads `sources` since PR 7b).
  before do
    conn = ActiveRecord::Base.connection
    conn.execute(ActiveRecord::Base.sanitize_sql([<<~SQL.squish, weapon.id, page, Digest::SHA256.hexdigest(page)]))
      INSERT INTO weapon_sources (weapon_id, kind, key, body, sha256, fetched_at, page_kind, created_at, updated_at)
      VALUES (?, 'wiki_raw', 'Dread Scythe', ?, ?, now(), 'inline', now(), now())
    SQL
  end

  it 'rebuilds icon-flattened text from the stored page, without the network' do
    mangled = 'When main weapon (MC only): 20% Bonus DMG against foes with 25px|link=BurnedBurnedHP is lowered.'
    version = version_with("Dreadflame's Claws", mangled, position: 0)

    migrate

    clean = "'''When main weapon (MC only):''' 20% Bonus DMG against foes with {{status|Burned}}."
    expect(version.reload.description_en).to eq(clean)
    expect(version.skill.reload.description_en).to eq(clean)
    expect(WebMock).not_to have_requested(:any, /.*/)
  end

  it 'leaves a skill alone when a version has no stored tier to rebuild from' do
    mangled = 'Gain 25px|link=Charge BoostCharge Bar +10%.'
    version = version_with('Not On The Page', mangled, position: 2)

    migrate

    expect(version.reload.description_en).to eq(mangled)
    expect(version.skill.reload.description_en).to eq(mangled)
  end

  it "strips breaks that come from the page itself, and doesn't touch template-form skills" do
    glued = version_with("Hoarfrost's Heed", 'Small boost to DA rate (Big DMG)|s2_name=Tsunami\'s Might', position: 1)
    defaulted = version_with('Wicked Fangs', '{{{s2_desc|Gain {{status|DEF Down|t=1T}} instead.}}}<ref />',
                             position: 3)
    template = create(:skill, name_en: '{{{s1_4s_name|{{{s1_u1_name|}}}}}}',
                              description_en: '{{{ens1_4s_desc|{{{ens1_u1_desc|}}}}}}')

    migrate

    expect(glued.reload.description_en).to eq('Small boost to DA rate (Big DMG)')
    expect(glued.skill.reload.description_en).to eq('Small boost to DA rate (Big DMG)')
    expect(defaulted.reload.description_en).to eq('Gain {{status|DEF Down|t=1T}} instead.<ref />')
    expect(template.reload.description_en).to eq('{{{ens1_4s_desc|{{{ens1_u1_desc|}}}}}}')
  end

  it 'changes nothing on a second run' do
    version_with("Dreadflame's Claws", 'Foes with 25px|link=BurnedBurned.', position: 0)
    migrate
    before = [Skill.pluck(:id, :description_en).sort, WeaponSkillVersion.pluck(:id, :description_en).sort]

    migrate

    expect([Skill.pluck(:id, :description_en).sort, WeaponSkillVersion.pluck(:id, :description_en).sort]).to eq(before)
  end
end
