class Job < ApplicationRecord
    belongs_to :party

    def display_resource(job)
        job.name_en
    end
end
