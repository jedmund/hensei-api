# frozen_string_literal: true

class Summon < ApplicationRecord
  include PgSearch::Model

  pg_search_scope :en_search,
                  against: :name_en,
                  using: {
                    trigram: {
                      threshold: 0.18
                    }
                  }

  pg_search_scope :jp_search,
                  against: :name_jp,
                  using: {
                    tsearch: {
                      prefix: true,
                      dictionary: 'simple'
                    }
                  }

  def display_resource(summon)
    summon.name_en
  end
end
