# frozen_string_literal: true

class AddDescriptionSegmentsToCharacterSkillVersions < ActiveRecord::Migration[8.1]
  def change
    # The English description as display segments (CharacterSkills::DescriptionMarkup),
    # written by the skill build.
    add_column :character_skill_versions, :description_segments, :jsonb
  end
end
