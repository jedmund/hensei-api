# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Weapon-skill referential integrity' do
  let(:version) { create(:weapon_skill_version) }

  it 'refuses to destroy a skill that weapon versions still use' do
    skill = version.skill

    expect(skill.destroy).to be(false)
    expect(skill.errors[:base]).to be_present
    expect(WeaponSkillVersion.exists?(version.id)).to be(true)
  end

  it 'destroys a skill with no weapon versions' do
    skill = create(:skill)

    expect { skill.destroy }.to change(Skill, :count).by(-1)
  end

  it 'deletes version-linked data and effects with their version' do
    datum = create(:weapon_skill_datum, weapon_skill_version_id: version.id)
    effect = WeaponSkillEffect.create!(weapon_skill_version_id: version.id, modifier: 'Spec', boost_type: 'atk',
                                       scaling_kind: 'static', value: 1.0, stacking: 'additive')

    WeaponSkillVersion.where(id: version.id).delete_all

    expect(WeaponSkillDatum.exists?(datum.id)).to be(false)
    expect(WeaponSkillEffect.exists?(effect.id)).to be(false)
  end

  it 'rejects a version-linked row whose version does not exist' do
    expect do
      create(:weapon_skill_datum, weapon_skill_version_id: SecureRandom.uuid)
    end.to raise_error(ActiveRecord::InvalidForeignKey)
  end
end
