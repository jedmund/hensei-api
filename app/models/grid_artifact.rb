# frozen_string_literal: true

class GridArtifact < ApplicationRecord
  include ArtifactSkillValidations

  # Associations
  belongs_to :grid_character
  belongs_to :artifact
  belongs_to :collection_artifact, optional: true

  has_one :party, through: :grid_character
  has_one :character, through: :grid_character

  # Orphan status scopes
  scope :orphaned, -> { where(orphaned: true) }
  scope :not_orphaned, -> { where(orphaned: false) }

  # Enums - using GranblueEnums::ELEMENTS values (excluding Null)
  # Wind: 1, Fire: 2, Water: 3, Earth: 4, Dark: 5, Light: 6
  enum :element, {
    wind: 1,
    fire: 2,
    water: 3,
    earth: 4,
    dark: 5,
    light: 6
  }

  # Proficiency enum - only used for quirk artifacts (game assigns random proficiency)
  enum :proficiency, {
    sabre: 1,
    dagger: 2,
    axe: 3,
    spear: 4,
    bow: 5,
    staff: 6,
    melee: 7,
    harp: 8,
    gun: 9,
    katana: 10
  }

  # Validations
  validates :element, presence: true
  validates :level, presence: true, inclusion: { in: 1..5 }
  validates :proficiency, presence: true, if: :quirk_artifact?
  validates :proficiency, absence: true, unless: :quirk_artifact?
  validates :reroll_slot, inclusion: { in: 1..4 }, allow_nil: true

  validate :validate_character_compatibility

  # Amoeba configuration for party duplication
  amoeba do
    enable
  end

  # Returns the effective proficiency - from instance for quirk, from artifact for standard
  def effective_proficiency
    quirk_artifact? ? proficiency : artifact&.proficiency
  end

  ##
  # Marks this grid artifact as orphaned and clears its collection link.
  #
  # @return [Boolean] true if the update succeeded
  def mark_orphaned!
    update!(orphaned: true, collection_artifact_id: nil)
  end

  ##
  # Syncs customizations from the linked collection artifact.
  #
  # @return [Boolean] true if sync was performed, false if no collection link
  def sync_from_collection!
    return false unless collection_artifact.present?

    attrs = {
      element: collection_artifact.element,
      level: collection_artifact.level,
      skill1: collection_artifact.skill1,
      skill2: collection_artifact.skill2,
      skill3: collection_artifact.skill3,
      skill4: collection_artifact.skill4,
      reroll_slot: collection_artifact.reroll_slot
    }

    # Only sync proficiency for quirk artifacts
    attrs[:proficiency] = collection_artifact.proficiency if quirk_artifact?

    update!(attrs)
    true
  end

  ##
  # Checks if grid artifact is out of sync with collection.
  #
  # @return [Boolean] true if any customization differs from collection
  def out_of_sync?
    return false unless collection_artifact.present?

    element != collection_artifact.element ||
      level != collection_artifact.level ||
      skill1 != collection_artifact.skill1 ||
      skill2 != collection_artifact.skill2 ||
      skill3 != collection_artifact.skill3 ||
      skill4 != collection_artifact.skill4 ||
      reroll_slot != collection_artifact.reroll_slot ||
      (quirk_artifact? && proficiency != collection_artifact.proficiency)
  end

  private

  def quirk_artifact?
    artifact&.quirk?
  end

  ##
  # Validates that the artifact's element and proficiency match the character's requirements.
  #
  # - Element must match the character's element (unless character has variable element like Lyria)
  # - Artifact's proficiency must match one of the character's proficiencies
  #
  # @return [void]
  def validate_character_compatibility
    return unless grid_character&.character && artifact

    char = grid_character.character

    # Check element compatibility
    # Characters with element=0 (Null) can equip any element artifact (e.g., Lyria)
    if char.element.present? && char.element != 0
      char_element = GranblueEnums::ELEMENTS.key(char.element)&.to_s&.downcase
      unless char_element == element
        errors.add(:element, "must match character's element (#{char_element})")
      end
    end

    # Check proficiency compatibility
    # Use effective_proficiency to get the right value for both standard and quirk artifacts
    eff_prof = effective_proficiency
    return unless eff_prof  # Skip if no proficiency available

    prof_value = Artifact.proficiencies[eff_prof]
    char_proficiencies = [char.proficiency1, char.proficiency2].compact

    unless char_proficiencies.include?(prof_value)
      errors.add(:artifact, "proficiency must match one of the character's proficiencies")
    end
  end
end
