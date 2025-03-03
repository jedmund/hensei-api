# frozen_string_literal: true

class Character < ApplicationRecord
  include PgSearch::Model

  multisearchable against: %i[name_en name_jp],
                  additional_attributes: lambda { |character|
                    {
                      name_en: character.name_en,
                      name_jp: character.name_jp,
                      granblue_id: character.granblue_id,
                      element: character.element
                    }
                  }

  pg_search_scope :en_search,
                  against: %i[name_en nicknames_en],
                  using: {
                    tsearch: {
                      prefix: true,
                      dictionary: 'simple'
                    },
                    trigram: {
                      threshold: 0.18
                    }
                  }

  pg_search_scope :ja_search,
                  against: %i[name_jp nicknames_jp],
                  using: {
                    tsearch: {
                      prefix: true,
                      dictionary: 'simple'
                    }
                  }

  has_many :character_skills,
           primary_key: 'granblue_id',
           foreign_key: 'character_granblue_id'
  has_many :skills,
           through: :character_skills
  has_many :charge_attacks,
           -> { where(owner_type: 'character') },
           primary_key: 'granblue_id',
           foreign_key: 'owner_id'

  AWAKENINGS = [
    { slug: 'character-balanced', name_en: 'Balanced', name_jp: 'バランス', order: 0 },
    { slug: 'character-atk', name_en: 'Attack', name_jp: '攻撃', order: 1 },
    { slug: 'character-def', name_en: 'Defense', name_jp: '防御', order: 2 },
    { slug: 'character-multi', name_en: 'Multiattack', name_jp: '連続攻撃', order: 3 }
  ].freeze

  def blueprint
    CharacterBlueprint
  end

  def display_resource(character)
    character.name_en
  end
end
