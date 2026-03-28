# frozen_string_literal: true

class Role < ApplicationRecord
  SLOT_TYPES = %w[Character Weapon Summon].freeze

  validates :name_en, presence: true
  validates :slot_type, presence: true, inclusion: { in: SLOT_TYPES }

  scope :for_slot, ->(type) { where(slot_type: type) }
end
