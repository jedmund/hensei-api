# frozen_string_literal: true

class ChargeAttack < ApplicationRecord
  belongs_to :skill
  belongs_to :alt_skill, class_name: 'Skill', optional: true

  validates :owner_id, presence: true
  validates :owner_type, presence: true
  validates :uncap_level, uniqueness: { scope: %i[owner_id owner_type] }

  scope :for_character, -> { where(owner_type: 'character') }
  scope :for_weapon, -> { where(owner_type: 'weapon') }
  scope :by_uncap_level, ->(level) { where(uncap_level: level) }
end
