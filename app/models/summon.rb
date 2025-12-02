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

  def blueprint
    SummonBlueprint
  end

  def display_resource(summon)
    summon.name_en
  end

  # Promotion scopes
  scope :by_promotion, ->(promotion) { where('? = ANY(promotions)', promotion) }
  scope :in_premium, -> { by_promotion(GranblueEnums::PROMOTIONS[:Premium]) }
  scope :in_classic, -> { by_promotion(GranblueEnums::PROMOTIONS[:Classic]) }
  scope :flash_exclusive, -> { by_promotion(GranblueEnums::PROMOTIONS[:Flash]).where.not('? = ANY(promotions)', GranblueEnums::PROMOTIONS[:Legend]) }
  scope :legend_exclusive, -> { by_promotion(GranblueEnums::PROMOTIONS[:Legend]).where.not('? = ANY(promotions)', GranblueEnums::PROMOTIONS[:Flash]) }

  # Promotion helpers
  def flash?
    promotions.include?(GranblueEnums::PROMOTIONS[:Flash])
  end

  def legend?
    promotions.include?(GranblueEnums::PROMOTIONS[:Legend])
  end

  def premium?
    promotions.include?(GranblueEnums::PROMOTIONS[:Premium])
  end

  def promotion_names
    promotions.filter_map { |p| GranblueEnums::PROMOTIONS.key(p)&.to_s }
  end
end
