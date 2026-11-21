# frozen_string_literal: true

##
# Shared by CollectionWonder and PartyWonder: the per-kind rules for level,
# evolution, possession and image, and the computed image and bonuses.
#
# - leveled: level from 1 to the cap (the Seal's evolution cap, or
#   max_level), evolution from 0 to max_evolution (0 when not given).
# - scaling: possession >= 0; image is the game's variant (e.g. 9015_10).
# - fixed: none of these.
module WonderHolding
  extend ActiveSupport::Concern

  included do
    belongs_to :wonder

    before_validation :default_evolution

    validates :level, numericality: { only_integer: true }, allow_nil: true
    validates :evolution, numericality: { only_integer: true }, allow_nil: true
    validates :possession, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
    validate :fields_fit_kind
  end

  # The image file name: `<granblue_id>_<level>` for leveled Wonders, the
  # stored variant (or the granblue_id) for scaling ones, else the granblue_id.
  def image_name
    granblue_id = wonder.granblue_id
    if wonder.leveled?
      "#{granblue_id}_#{level}"
    elsif wonder.scaling?
      image.presence || granblue_id
    else
      granblue_id
    end
  end

  def bonuses
    wonder.bonuses_at(level: level, possession: possession)
  end

  private

  def default_evolution
    self.evolution = 0 if evolution.nil? && wonder&.leveled?
  end

  def fields_fit_kind
    return unless wonder

    validate_leveled_fields
    validate_scaling_fields
    %i[level evolution].each { |field| errors.add(field, 'is only for leveled Wonders') if !wonder.leveled? && self[field] }
    %i[possession image].each { |field| errors.add(field, 'is only for Symbolum') if !wonder.scaling? && self[field] }
  end

  def validate_leveled_fields
    return unless wonder.leveled?

    unless evolution.is_a?(Integer) && evolution.between?(0, wonder.max_evolution)
      errors.add(:evolution, "must be from 0 to #{wonder.max_evolution}")
      return
    end

    cap = wonder.level_cap(evolution)
    return if level.is_a?(Integer) && cap && level.between?(1, cap)

    errors.add(:level, cap ? "must be from 1 to #{cap}" : 'has no cap at this evolution')
  end

  def validate_scaling_fields
    return unless wonder.scaling? && image.present?
    return if image.match?(/\A#{Regexp.escape(wonder.granblue_id)}(?:_\d{1,3})?\z/)

    errors.add(:image, 'is not an image of this Wonder')
  end
end
