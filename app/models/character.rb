class Character < ApplicationRecord
    include PgSearch::Model

    pg_search_scope :search, 
        against: [:name_en, :name_jp],
        using: {
            tsearch: {
                negation: true,
                prefix: true
            }
        }

    def display_resource(character)
        character.name_en
    end
end
