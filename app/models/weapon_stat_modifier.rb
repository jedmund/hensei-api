# frozen_string_literal: true

##
# Reference table for weapon stat modifiers (AX skills and befoulments).
#
# AX skills are positive modifiers that can be applied to certain weapons.
# Befoulments are negative modifiers that appear on Odiant weapons.
#
class WeaponStatModifier < ApplicationRecord
  CATEGORIES = %w[ax befoulment].freeze
  AX_SECONDARY_POOLS = {
    "ax_atk" => { "standard" => %w[ax_ca_dmg ax_da ax_ta ax_skill_cap],
                  "xeno" => %w[ax_ca_dmg ax_multiattack ax_na_cap ax_skill_supp] },
    "ax_def" => { "standard" => %w[ax_hp ax_debuff_res ax_healing ax_enmity],
                  "xeno" => %w[ax_ele_dmg_red ax_debuff_res ax_healing ax_enmity] },
    "ax_hp" => { "standard" => %w[ax_def ax_debuff_res ax_healing ax_stamina],
                 "xeno" => %w[ax_ele_dmg_red ax_debuff_res ax_healing ax_stamina] },
    "ax_ca_dmg" => { "standard" => %w[ax_atk ax_ele_atk ax_ca_cap ax_stamina],
                     "xeno" => %w[ax_multiattack ax_skill_supp ax_ca_supp ax_stamina] },
    "ax_multiattack" => { "standard" => %w[ax_ca_dmg ax_ele_atk ax_da ax_ta],
                          "xeno" => %w[ax_ca_supp ax_na_cap ax_stamina ax_enmity] }
  }.freeze
  AX_SECONDARY_RANGES = {
    "ax_atk" => [1, 1.5], "ax_ele_atk" => [1, 5], "ax_na_cap" => [0.5, 1.5],
    "ax_def" => [1, 3], "ax_hp" => [1, 3], "ax_debuff_res" => [1, 3],
    "ax_healing" => [2, 5], "ax_ele_dmg_red" => [1, 5], "ax_stamina" => [1, 3],
    "ax_enmity" => [1, 3], "ax_ca_dmg" => [2, 4], "ax_ca_cap" => [1, 2],
    "ax_ca_supp" => [1, 5], "ax_skill_cap" => [1, 2], "ax_skill_supp" => [1, 5],
    "ax_multiattack" => [1, 2], "ax_da" => [1, 2], "ax_ta" => [1, 2]
  }.freeze

  validates :slug, presence: true, uniqueness: true
  validates :name_en, presence: true
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :polarity, inclusion: { in: [-1, 1] }

  scope :ax_skills, -> { where(category: 'ax') }
  scope :befoulments, -> { where(category: 'befoulment') }

  def self.find_by_game_skill_id(id)
    find_by(game_skill_id: id.to_i)
  end

  def buff?
    polarity == 1
  end

  def debuff?
    polarity == -1
  end
end
