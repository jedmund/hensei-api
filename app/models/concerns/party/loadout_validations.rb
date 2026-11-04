# frozen_string_literal: true

##
# Validations for the MC loadout: unique job skills, unique guidebooks and
# the per-slot Full Auto toggles.
#
# Party includes this after its associations, so these run after the
# associated-record validations, as they did when declared in the class.
module Party::LoadoutValidations
  extend ActiveSupport::Concern

  # full_auto_skills maps an MC ability slot ("0".."3") to whether it is used in
  # Full Auto. Reject unknown slots or non-boolean values.
  FULL_AUTO_SLOTS = %w[0 1 2 3].freeze
  private_constant :FULL_AUTO_SLOTS
  FULL_AUTO_VALUES = [true, false].freeze
  private_constant :FULL_AUTO_VALUES

  included do
    validate :skills_are_unique
    validate :guidebooks_are_unique
    validate :validate_full_auto_skills
  end

  private

  ##
  # Validates uniqueness for a given set of associations.
  #
  # @param associations [Array<Object, nil>] an array of associated objects.
  # @param attribute_names [Array<Symbol>] the corresponding attribute names for each association.
  # @param error_key [Symbol] the key for a generic error.
  # @return [void]
  def validate_uniqueness_of_associations(associations, attribute_names, error_key)
    filtered = associations.compact
    return if filtered.uniq.length == filtered.length

    associations.each_with_index do |assoc, index|
      next if assoc.nil?

      errors.add(attribute_names[index], 'must be unique') if associations[0...index].include?(assoc)
    end
    errors.add(error_key, 'must be unique')
  end

  ##
  # Validates that the selected skills are unique.
  #
  # @return [void]
  def skills_are_unique
    validate_uniqueness_of_associations([skill0, skill1, skill2, skill3],
                                        %i[skill0 skill1 skill2 skill3],
                                        :job_skills)
  end

  ##
  # Validates that the selected guidebooks are unique.
  #
  # @return [void]
  def guidebooks_are_unique
    validate_uniqueness_of_associations([guidebook1, guidebook2, guidebook3],
                                        %i[guidebook1 guidebook2 guidebook3],
                                        :guidebooks)
  end

  ##
  # Validates the per-slot MC Full Auto toggles.
  #
  # @return [void]
  def validate_full_auto_skills
    return if full_auto_skills.blank?

    unless full_auto_skills.is_a?(Hash)
      errors.add(:full_auto_skills, 'must be an object')
      return
    end

    full_auto_skills.each do |slot, value|
      errors.add(:full_auto_skills, "invalid slot #{slot}") unless FULL_AUTO_SLOTS.include?(slot.to_s)
      errors.add(:full_auto_skills, "invalid value for slot #{slot}") unless FULL_AUTO_VALUES.include?(value)
    end
  end
end
