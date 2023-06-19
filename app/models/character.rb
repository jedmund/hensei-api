# frozen_string_literal: true

class Character < ApplicationRecord
  include PgSearch::Model

  pg_search_scope :en_search,
                  against: :name_en,
                  using: {
                    trigram: {
                      threshold: 0.18
                    }
                  }

  pg_search_scope :ja_search,
                  against: :name_jp,
                  using: {
                    tsearch: {
                      prefix: true,
                      dictionary: 'simple'
                    }
                  }

  def blueprint
    CharacterBlueprint
  end

  def display_resource(character)
    character.name_en
  end

  # enum rarities: {
  #     R:   1,
  #     SR:  2,
  #     SSR: 3
  # }

  # enum elements: {
  #     Null:   0,
  #     Wind:   1,
  #     Fire:   2,
  #     Water:  3,
  #     Earth:  4,
  #     Dark:   5,
  #     Light:  6
  # }

  # enum proficiency1s: {
  #     Sabre:  1,
  #     Dagger: 2,
  #     Axe:    3,
  #     Spear:  4,
  #     Bow:    5,
  #     Staff:  6,
  #     Melee:  7,
  #     Harp:   8,
  #     Gun:    9,
  #     Katana: 10
  # }, _prefix: "proficiency1"

  # enum proficiency2s: {
  #     None:   0,
  #     Sabre:  1,
  #     Dagger: 2,
  #     Axe:    3,
  #     Spear:  4,
  #     Bow:    5,
  #     Staff:  6,
  #     Melee:  7,
  #     Harp:   8,
  #     Gun:    9,
  #     Katana: 10,
  # }, _default: :None, _prefix: "proficiency2"

  # enum race1s: {
  #     Unknown: 0,
  #     Human:   1,
  #     Erune:   2,
  #     Draph:   3,
  #     Harvin:  4,
  #     Primal:  5
  # }, _prefix: "race1"

  # enum race2s: {
  #     Unknown: 0,
  #     Human:   1,
  #     Erune:   2,
  #     Draph:   3,
  #     Harvin:  4,
  #     Primal:  5,
  #     None:    6
  # }, _default: :None, _prefix: "race2"

  # enum gender: {
  #     Unknown:    0,
  #     Male:       1,
  #     Female:     2,
  #     "Male/Female": 3
  # }
end
