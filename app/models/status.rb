# frozen_string_literal: true

# A buff, debuff, field effect or instant effect a skill can apply. `category` is the status's
# *usual* category: buff or debuff belongs to each skill effect (skill_effects.category, D36; the
# game colours the same status per skill), and this is the majority over its effects, or gbf.wiki's
# table when they tie or there are none. `mixed` is true when its effects really split (some buff,
# some debuff, e.g. Hostility Up: Seox's buff, Clarisse (Light)'s self-inflicted debuff).
#
# `wiki_name` is the status's identity, the wiki name the skill build keys it by (`name_key` is it
# normalized); `name_en` is the name shown, without the wiki's trailing level number ("Jade Crest 1"
# shows as Jade Crest, D59). Two statuses that show the same name are told apart by `qualifier`
# ("Asleep" and "Asleep" (Turns)); (name_en, qualifier) is unique. CharacterSkills::StatusDisplayNames
# sets both.
class Status < ApplicationRecord
  # Dropped in the next migration; ignored first so running code never reads it.
  self.ignored_columns += ['game_ailment_id']

  has_many :skill_effects, dependent: :nullify

  enum :category, { buff: 'buff', debuff: 'debuff', field: 'field', special: 'special' }

  # Also before_save: a save that skips validation still gets its key.
  before_validation :assign_wiki_name, :assign_name_key
  before_save :assign_wiki_name, :assign_name_key

  validates :name_en, presence: true

  scope :in_family, ->(name) { where(family: name) }
  scope :named, ->(names) { where(name_key: Array(names).map { |name| normalize_name(name) }) }

  # How a name is compared, computed in Ruby so it doesn't depend on the database's locale:
  # Unicode-composed, any whitespace squished, Unicode-downcased. One status per key
  # (statuses.name_key, unique).
  def self.normalize_name(name)
    name.to_s.unicode_normalize(:nfc).squish.downcase
  end

  # Splits a leveled status name ("Paralyzed 2") into [family, level].
  # Returns [nil, nil] when the name carries no trailing level.
  def self.split_family_and_level(name)
    match = name.to_s.match(/\A(.+?)\s+(\d+)\z/)
    return [nil, nil] unless match

    [match[1], match[2].to_i]
  end

  private

  def assign_wiki_name
    self.wiki_name = name_en if wiki_name.blank?
  end

  def assign_name_key
    self.name_key = self.class.normalize_name(wiki_name.presence || name_en)
  end
end
