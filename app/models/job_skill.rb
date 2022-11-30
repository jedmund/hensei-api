class JobSkill < ApplicationRecord
  include PgSearch::Model

  belongs_to :job

  pg_search_scope :en_search, 
        against: :name_en,
        using: {
            tsearch: {
                prefix: true,
                dictionary: "simple"
            }
        }

    pg_search_scope :jp_search, 
        against: :name_jp,
        using: {
            tsearch: {
                prefix: true,
                dictionary: "simple"
            }
        }

  def display_resource(skill)
    skill.name_en
  end
end
