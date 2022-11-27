class JobSkill < ApplicationRecord
  belongs_to :job

  def display_resource(skill)
    skill.name_en
  end
end
