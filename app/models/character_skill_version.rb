# frozen_string_literal: true

class CharacterSkillVersion < ApplicationRecord
  belongs_to :character_skill, inverse_of: :character_skill_versions
  has_many :skill_effects, -> { order(:ordinal) }, dependent: :destroy, inverse_of: :character_skill_version

  has_many :outgoing_links, class_name: 'CharacterSkillVersionLink', foreign_key: :from_version_id,
                            dependent: :destroy, inverse_of: :from_version
  has_many :incoming_links, class_name: 'CharacterSkillVersionLink', foreign_key: :to_version_id,
                            dependent: :destroy, inverse_of: :to_version

  enum :type_color, { damage: 'damage', heal: 'heal', buff: 'buff', debuff: 'debuff', field: 'field' },
       prefix: :color
  enum :variant_role, { base: 'base', enhanced: 'enhanced', uncap_upgrade: 'uncap_upgrade',
                        transcendence_upgrade: 'transcendence_upgrade', transform_alt: 'transform_alt',
                        option: 'option', form_alt: 'form_alt', conditional: 'conditional' }
  enum :trigger_type, { none: 'none', on_cast_toggle: 'on_cast_toggle', stack_threshold: 'stack_threshold',
                        field_effect: 'field_effect', form_state: 'form_state', menu_select: 'menu_select',
                        contextual: 'contextual' }, prefix: :trigger
  enum :duration_unit, { turns: 'turns', half_turns: 'half_turns', seconds: 'seconds',
                         indefinite: 'indefinite', one_time: 'one_time', none: 'none' }, prefix: :duration

  validates :name_en, presence: true
  validates :ordinal, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :variant_role, presence: true
end
