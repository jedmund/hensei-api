# frozen_string_literal: true

# The character-skill build stores the digest of each character's inputs here after a write
# (CharacterSkills::Build::Fingerprint); a character whose inputs still match isn't rebuilt.
class AddCharacterSkillBuildFingerprintToCharacters < ActiveRecord::Migration[8.1]
  def change
    add_column :characters, :character_skill_build_fingerprint, :string
  end
end
