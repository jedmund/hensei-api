class Favorite < ApplicationRecord
    belongs_to :user

    def party
        Party.find(self.party_id)
    end
end
