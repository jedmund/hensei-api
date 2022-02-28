class Favorite < ApplicationRecord
    belongs_to :user
    has_one :party

    def party
        Party.find(self.party_id)
    end
end
