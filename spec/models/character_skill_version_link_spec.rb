# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CharacterSkillVersionLink, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:from_version).class_name('CharacterSkillVersion').inverse_of(:outgoing_links) }
    it { is_expected.to belong_to(:to_version).class_name('CharacterSkillVersion').inverse_of(:incoming_links) }
  end

  describe 'enums' do
    it 'defines relation enum' do
      expect(described_class.relations).to eq(
        'transforms_to' => 'transforms_to',
        'option_of' => 'option_of',
        'form_counterpart' => 'form_counterpart'
      )
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:relation) }

    it 'validates uniqueness scoped to endpoints and relation' do
      existing = create(:character_skill_version_link, relation: :transforms_to)
      duplicate = build(
        :character_skill_version_link,
        from_version: existing.from_version,
        to_version: existing.to_version,
        relation: :transforms_to
      )

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:from_version_id]).to include('has already been taken')
    end

    it 'allows the same endpoints with a different relation' do
      existing = create(:character_skill_version_link, relation: :transforms_to)
      option_link = build(
        :character_skill_version_link,
        from_version: existing.from_version,
        to_version: existing.to_version,
        relation: :option_of
      )

      expect(option_link).to be_valid
    end
  end
end
