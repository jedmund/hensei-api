# frozen_string_literal: true

class Job < ApplicationRecord
  include PgSearch::Model

  belongs_to :party, optional: true
  has_many :skills, class_name: 'JobSkill'

  multisearchable against: %i[name_en name_jp],
                  additional_attributes: lambda { |job|
                    {
                      name_en: job.name_en,
                      name_jp: job.name_jp,
                      granblue_id: job.granblue_id,
                      element: 0
                    }
                  }

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
