# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Parsers::CharacterSkills::Persister do
  let(:character) { create(:character, granblue_id: '3990000000') }

  let(:graph) do
    {
      slots: [
        {
          attrs: { character_granblue_id: character.granblue_id, kind: 'ability', position: 1, bogus: 'drop me' },
          versions: [
            { key: 'v1', attrs: { name_en: 'Base', variant_role: 'base', ordinal: 1 },
              effects: [{ ordinal: 1, effect_type: 'grant_status', target: 'caster', junk: 'x' }] },
            { key: 'v2', attrs: { name_en: 'Alt', variant_role: 'transform_alt', ordinal: 2 }, effects: [] }
          ]
        }
      ],
      links: [
        { from_version_key: 'v1', to_version_key: 'v2', relation: 'transforms_to' },
        { from_version_key: 'v1', to_version_key: 'missing', relation: 'transforms_to' } # dangling — skipped
      ]
    }
  end

  it 'creates slots, versions, effects, and links, dropping unknown attribute keys' do
    described_class.new(character).persist(graph)

    skill = CharacterSkill.find_by(character_granblue_id: character.granblue_id, kind: 'ability', position: 1)
    base = skill.character_skill_versions.find_by(name_en: 'Base')

    aggregate_failures do
      expect(skill.character_skill_versions.pluck(:name_en)).to contain_exactly('Base', 'Alt')
      expect(base.skill_effects.pluck(:effect_type, :target)).to eq([%w[grant_status caster]])
      expect(CharacterSkillVersionLink.where(from_version_id: base.id).pluck(:relation)).to eq(['transforms_to'])
    end
  end

  it 're-persists idempotently (destroy then recreate)' do
    described_class.new(character).persist(graph)
    described_class.new(character).persist(graph)

    expect(CharacterSkill.where(character_granblue_id: character.granblue_id).count).to eq(1)
  end
end
