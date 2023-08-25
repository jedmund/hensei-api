# frozen_string_literal: true

class Party < ApplicationRecord
  ##### ActiveRecord Associations
  belongs_to :source_party,
             class_name: 'Party',
             foreign_key: :source_party_id,
             optional: true

  has_many :derivative_parties,
           class_name: 'Party',
           foreign_key: :source_party_id,
           inverse_of: :source_party,
           dependent: :nullify

  belongs_to :user, optional: true
  belongs_to :raid, optional: true
  belongs_to :job, optional: true

  belongs_to :accessory,
             foreign_key: 'accessory_id',
             class_name: 'JobAccessory',
             optional: true

  belongs_to :skill0,
             foreign_key: 'skill0_id',
             class_name: 'JobSkill',
             optional: true

  belongs_to :skill1,
             foreign_key: 'skill1_id',
             class_name: 'JobSkill',
             optional: true

  belongs_to :skill2,
             foreign_key: 'skill2_id',
             class_name: 'JobSkill',
             optional: true

  belongs_to :skill3,
             foreign_key: 'skill3_id',
             class_name: 'JobSkill',
             optional: true

  belongs_to :guidebook1,
             foreign_key: 'guidebook1_id',
             class_name: 'Guidebook',
             optional: true

  belongs_to :guidebook2,
             foreign_key: 'guidebook2_id',
             class_name: 'Guidebook',
             optional: true

  belongs_to :guidebook3,
             foreign_key: 'guidebook3_id',
             class_name: 'Guidebook',
             optional: true

  has_many :characters,
           foreign_key: 'party_id',
           class_name: 'GridCharacter',
           dependent: :destroy,
           inverse_of: :party

  has_many :weapons,
           foreign_key: 'party_id',
           class_name: 'GridWeapon',
           dependent: :destroy,
           inverse_of: :party

  has_many :summons,
           foreign_key: 'party_id',
           class_name: 'GridSummon',
           dependent: :destroy,
           inverse_of: :party

  has_many :favorites, dependent: :destroy

  before_create :set_shortcode
  before_create :set_edit_key

  ##### Amoeba configuration
  amoeba do
    set weapons_count: 0
    set characters_count: 0
    set summons_count: 0

    nullify :description
    nullify :shortcode

    include_association :characters
    include_association :weapons
    include_association :summons
  end

  ##### ActiveRecord Validations
  validate :skills_are_unique
  validate :guidebooks_are_unique

  attr_accessor :favorited

  def is_favorited(user)
    user.favorite_parties.include? self if user
  end

  def is_remix
    !source_party.nil?
  end

  def remixes
    Party.where(source_party_id: id)
  end

  def blueprint
    PartyBlueprint
  end

  def public?
    visibility == 1
  end

  def unlisted?
    visibility == 2
  end

  def private?
    visibility == 3
  end

  private

  def set_shortcode
    self.shortcode = random_string
  end

  def set_edit_key
    return if user

    self.edit_key = Digest::SHA1.hexdigest([Time.now, rand].join)
  end

  def random_string
    num_chars = 6
    o = [('a'..'z'), ('A'..'Z'), (0..9)].map(&:to_a).flatten
    (0...num_chars).map { o[rand(o.length)] }.join
  end

  def skills_are_unique
    skills = [skill0, skill1, skill2, skill3].compact

    return if skills.uniq.length == skills.length

    skills.each_with_index do |skill, index|
      next if index.zero?

      errors.add(:"skill#{index + 1}", 'must be unique') if skills[0...index].include?(skill)
    end

    errors.add(:job_skills, 'must be unique')
  end

  def guidebooks_are_unique
    guidebooks = [guidebook1, guidebook2, guidebook3].compact
    return if guidebooks.uniq.length == guidebooks.length

    guidebooks.each_with_index do |book, index|
      next if index.zero?

      errors.add(:"guidebook#{index + 1}", 'must be unique') if guidebooks[0...index].include?(book)
    end

    errors.add(:guidebooks, 'must be unique')
  end
end
