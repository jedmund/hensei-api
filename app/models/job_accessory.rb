# frozen_string_literal: true

class JobAccessory < ApplicationRecord
  include PgSearch::Model

  belongs_to :job

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
    JobAccessoryBlueprint
  end

  def display_resource(skill)
    skill.name_en
  end

  def ==(other)
    self.class == other.class && id == other.id
  end
end
