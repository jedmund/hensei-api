# frozen_string_literal: true

class SkillEffect < ApplicationRecord
  belongs_to :character_skill_version, inverse_of: :skill_effects
  belongs_to :status, optional: true

  enum :effect_type, { grant_status: 'grant_status', inflict_status: 'inflict_status',
                       deal_damage: 'deal_damage', heal: 'heal', dispel: 'dispel',
                       cooldown_manip: 'cooldown_manip', charge_manip: 'charge_manip',
                       field_effect: 'field_effect', summon_object: 'summon_object',
                       weapon_skill_boost: 'weapon_skill_boost',
                       other: 'other' }, prefix: :effect

  # Passive support skills that amplify the grid (e.g. Hudor Arche). `frame`/`element`
  # say which summon-aura frame they add to; `amount` is the percent.
  scope :weapon_skill_boosts, -> { effect_weapon_skill_boost }
  enum :target, { caster: 'caster', one_ally: 'one_ally', all_allies: 'all_allies',
                  element_allies: 'element_allies', one_foe: 'one_foe', all_foes: 'all_foes',
                  field: 'field' }, prefix: :target
  enum :duration_unit, { turns: 'turns', half_turns: 'half_turns', seconds: 'seconds',
                         indefinite: 'indefinite', one_time: 'one_time', none: 'none' },
       prefix: :duration
  enum :stacking_frame, { normal: 'normal', summon: 'summon', unique: 'unique', seraphic: 'seraphic',
                          ex: 'ex', assassin: 'assassin' }, prefix: :stacking

  validates :ordinal, presence: true
  validates :effect_type, presence: true
end
