# frozen_string_literal: true

class Guidebook < ApplicationRecord
  alias eql? ==

  include PgSearch::Model

  pg_search_scope :en_search,
                  against: :name_en,
                  using: {
                    tsearch: {
                      prefix: true,
                      dictionary: 'simple'
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

  def blueprint
    GuidebookBlueprint
  end

  def display_resource(book)
    book.name_en
  end

  def ==(other)
    self.class == other.class && granblue_id === other.granblue_id
  end
end
