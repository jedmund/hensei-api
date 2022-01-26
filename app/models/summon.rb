class Summon < ApplicationRecord
    include PgSearch::Model

    pg_search_scope :search, 
        against: [:name_en, :name_jp],
        using: {
            tsearch: {
                prefix: true
            }
        }

    def display_resource(summon)
        summon.name_en
    end
end
