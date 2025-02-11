# frozen_string_literal: true

class Party < ApplicationRecord
  ##### ActiveRecord Associations
  belongs_to :source_party,
             class_name: 'Party',
             foreign_key: :source_party_id,
             optional: true

  has_many :remixes, -> { order(created_at: :desc) },
           class_name: 'Party',
           foreign_key: 'source_party_id',
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
           counter_cache: true,
           dependent: :destroy,
           inverse_of: :party

  has_many :weapons,
           foreign_key: 'party_id',
           class_name: 'GridWeapon',
           counter_cache: true,
           dependent: :destroy,
           inverse_of: :party

  has_many :summons,
           foreign_key: 'party_id',
           class_name: 'GridSummon',
           counter_cache: true,
           dependent: :destroy,
           inverse_of: :party

  has_many :favorites, dependent: :destroy

  accepts_nested_attributes_for :characters
  accepts_nested_attributes_for :summons
  accepts_nested_attributes_for :weapons

  before_create :set_shortcode
  before_create :set_edit_key

  after_commit :update_element!, on: %i[create update]
  after_commit :update_extra!, on: %i[create update]

  ##### Amoeba configuration
  amoeba do
    set weapons_count: 0
    set characters_count: 0
    set summons_count: 0

    nullify :description
    nullify :shortcode
    nullify :edit_key

    include_association :characters
    include_association :weapons
    include_association :summons
  end

  ##### ActiveRecord Validations
  validate :skills_are_unique
  validate :guidebooks_are_unique

  self.enum :preview_state, {
    pending: 0,
    queued: 1,
    in_progress: 2,
    generated: 3,
    failed: 4
  }

  after_commit :schedule_preview_generation, if: :should_generate_preview?

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

  def is_favorited(user)
    return false unless user

    Rails.cache.fetch("party_#{id}_favorited_by_#{user.id}", expires_in: 1.hour) do
      user.favorite_parties.include?(self)
    end
  end

  def ready_for_preview?
    return false if weapons_count < 1 # At least 1 weapon
    return false if characters_count < 1 # At least 1 character
    return false if summons_count < 1 # At least 1 summon
    true
  end

  def should_generate_preview?
    return false unless ready_for_preview?

    # Always generate if no preview exists
    return true if preview_state.nil? || preview_state == 'pending'

    # Generate if failed and enough time has passed for conditions to change
    return true if preview_state == 'failed' && preview_generated_at < 5.minutes.ago

    # Generate if preview is old
    return true if preview_state == 'generated' && preview_expired?

    # Only regenerate on content changes if the last generation was > 5 minutes ago
    # This prevents rapid regeneration during party building
    if preview_content_changed?
      return true if preview_generated_at.nil? || preview_generated_at < 5.minutes.ago
    end

    false
  end

  def preview_expired?
    preview_generated_at.nil? ||
      preview_generated_at < PreviewService::Coordinator::PREVIEW_EXPIRY.ago
  end

  def preview_content_changed?
    saved_changes.keys.any? { |attr| preview_relevant_attributes.include?(attr) }
  end

  def schedule_preview_generation
    return if preview_state == 'queued' || preview_state == 'in_progress'

    update_column(:preview_state, 'queued')
    GeneratePartyPreviewJob.perform_later(id)
  end

  private

  def update_element!
    main_weapon = weapons.detect { |gw| gw.position.to_i == -1 }
    new_element = main_weapon&.weapon&.element
    if new_element.present? && self.element != new_element
      update_column(:element, new_element)
    end
  end

  def update_extra!
    new_extra = weapons.any? { |gw| GridWeapon::EXTRA_POSITIONS.include?(gw.position.to_i) }
    if self.extra != new_extra
      update_column(:extra, new_extra)
    end
  end

  def set_shortcode
    self.shortcode = random_string
  end

  def set_edit_key
    return if user

    self.edit_key ||= Digest::SHA1.hexdigest([Time.now, rand].join)
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

  def preview_relevant_attributes
    %w[
      name job_id element weapons_count characters_count summons_count
      full_auto auto_guard charge_attack clear_time
    ]
  end
end
