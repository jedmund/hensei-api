class Favorite < ApplicationRecord
    belongs_to :user
    belongs_to :party

    def party
        Party.find(self.party_id)
    end
end
