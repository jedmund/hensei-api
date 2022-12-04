class Party < ApplicationRecord
  ##### ActiveRecord Associations
  belongs_to :user, optional: true
  belongs_to :raid, optional: true
  belongs_to :job, optional: true

  belongs_to :skill0,
             foreign_key: "skill0_id",
             class_name: "JobSkill",
             optional: true

  belongs_to :skill1,
             foreign_key: "skill1_id",
             class_name: "JobSkill",
             optional: true

  belongs_to :skill2,
             foreign_key: "skill2_id",
             class_name: "JobSkill",
             optional: true

  belongs_to :skill3,
             foreign_key: "skill3_id",
             class_name: "JobSkill",
             optional: true

  has_many :characters,
           foreign_key: "party_id",
           class_name: "GridCharacter",
           dependent: :destroy

  has_many :weapons,
           foreign_key: "party_id",
           class_name: "GridWeapon",
           dependent: :destroy

  has_many :summons,
           foreign_key: "party_id",
           class_name: "GridSummon",
           dependent: :destroy

  has_many :favorites

  ##### ActiveRecord Validations
  validate :skills_are_unique

  attr_accessor :favorited

  def is_favorited(user)
    user.favorite_parties.include? self
  end

  private

  def skills_are_unique
    skills = [skill0, skill1, skill2, skill3].compact

    if skills.uniq.length != skills.length
      errors.add(:skill1, "must be unique") if skill0 == skill1

      if skill0 == skill2 || skill1 == skill2
        errors.add(:skill2, "must be unique")
      end

      if skill0 == skill3 || skill1 == skill3 || skill2 == skill3
        errors.add(:skill3, "must be unique")
      end

      errors.add(:job_skills, "must be unique")
    end
  end
end
