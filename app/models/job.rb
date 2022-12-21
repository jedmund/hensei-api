# frozen_string_literal: true

class Job < ApplicationRecord
  belongs_to :party

  belongs_to :base_job,
             foreign_key: 'base_job_id',
             class_name: 'Job',
             optional: true

  def display_resource(job)
    job.name_en
  end
end
