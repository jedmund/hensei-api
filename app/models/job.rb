class Job < ApplicationRecord
    belongs_to :party
    
    def display_resource(class)
        class.name_en
    end
end
