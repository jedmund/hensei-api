class GridCharacter < ApplicationRecord
    belongs_to :party

    def character
        Character.find(self.character_id)
    end
end
