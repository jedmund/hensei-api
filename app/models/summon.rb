# frozen_string_literal: true

class Summon < ApplicationRecord
  include PgSearch::Model

  multisearchable against: %i[name_en name_jp],
                  additional_attributes: lambda { |summon|
                    {
                      name_en: summon.name_en,
                      name_jp: summon.name_jp,
                      granblue_id: summon.granblue_id,
                      element: summon.element
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

  has_many :summon_calls,
           primary_key: 'granblue_id',
           foreign_key: 'summon_granblue_id'
  has_many :summon_auras,
           primary_key: 'granblue_id',
           foreign_key: 'summon_granblue_id'
  has_many :skills,
           through: :summon_calls

  def blueprint
    SummonBlueprint
  end

  def display_resource(summon)
    summon.name_en
  end
end
