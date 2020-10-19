class GridSummon < ApplicationRecord
    belongs_to :party

    def summon
        Summon.find(self.summon_id)
    end
end
