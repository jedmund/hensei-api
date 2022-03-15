class PopulatePartyWeaponsCount < ActiveRecord::Migration[6.1]
    def up
        Party.find_each do |party|
            Party.reset_counters(party.id, :weapons)
        end
    end
end
