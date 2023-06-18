# frozen_string_literal: true

class Job < ApplicationRecord
  belongs_to :party
  has_many :skills, class_name: 'JobSkill'

  belongs_to :base_job,
             foreign_key: 'base_job_id',
             class_name: 'Job',
             optional: true

  def blueprint
    JobBlueprint
  end

  def display_resource(job)
    job.name_en
  end
end
