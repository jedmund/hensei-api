class CollectionCharacter < ApplicationRecord
  belongs_to :user
  belongs_to :character
  belongs_to :awakening, optional: true

  before_save :add_default_awakening

  validates :character_id, uniqueness: { scope: :user_id,
    message: "already exists in your collection" }
  validates :uncap_level, inclusion: { in: 0..6 }
  validates :transcendence_step, inclusion: { in: 0..10 }
  validates :awakening_level, inclusion: { in: 1..10 }

  validate :validate_rings
  validate :validate_awakening_compatibility
  validate :validate_awakening_level
  validate :validate_transcendence_requirements

  scope :by_element, ->(element) { joins(:character).where(characters: { element: element }) }
  scope :by_rarity, ->(rarity) { joins(:character).where(characters: { rarity: rarity }) }
  scope :by_race, ->(races) {
    joins(:character).where('characters.race1 IN (?) OR characters.race2 IN (?)', races, races)
  }
  scope :by_proficiency, ->(proficiencies) {
    joins(:character).where('characters.proficiency1 IN (?) OR characters.proficiency2 IN (?)', proficiencies, proficiencies)
  }
  scope :by_gender, ->(genders) { joins(:character).where(characters: { gender: genders }) }
  scope :by_series, ->(series_ids) {
    joins(character: :character_series_records)
      .where(character_series: { id: series_ids })
      .distinct
  }
  scope :by_name, ->(query) {
    joins(:character).where("characters.name_en ILIKE :q OR characters.name_jp ILIKE :q", q: "%#{sanitize_sql_like(query)}%")
  }
  scope :transcended, -> { where('transcendence_step > 0') }
  scope :with_awakening, -> { where.not(awakening_id: nil) }

  # Sorting scopes
  scope :sorted_by, ->(sort_key) {
    case sort_key
    when 'name_asc'
      joins(:character).order('characters.name_en ASC NULLS LAST')
    when 'name_desc'
      joins(:character).order('characters.name_en DESC NULLS LAST')
    when 'element_asc'
      joins(:character).order('characters.element ASC')
    when 'element_desc'
      joins(:character).order('characters.element DESC')
    when 'proficiency_asc'
      joins(:character).order('characters.proficiency1 ASC')
    when 'proficiency_desc'
      joins(:character).order('characters.proficiency1 DESC')
    else
      order(created_at: :desc) # Default: newest first
    end
  }

  def blueprint
    Api::V1::CollectionCharacterBlueprint
  end

  private

  def validate_rings
    [ring1, ring2, ring3, ring4, earring].each_with_index do |ring, index|
      next unless ring['modifier'].present? || ring['strength'].present?

      if ring['modifier'].blank? || ring['strength'].blank?
        errors.add(:base, "Ring #{index + 1} must have both modifier and strength")
      end
    end
  end

  def validate_awakening_compatibility
    return unless awakening.present?

    unless awakening.object_type == 'Character'
      errors.add(:awakening, "must be a character awakening")
    end
  end

  def validate_awakening_level
    if awakening_level.present? && awakening_level > 1 && awakening_id.blank?
      errors.add(:awakening_level, "cannot be set without an awakening")
    end
  end

  def validate_transcendence_requirements
    if transcendence_step.present? && transcendence_step > 0 && uncap_level < 5
      errors.add(:transcendence_step, "requires uncap level 5 (current: #{uncap_level})")
    end
  end

  def add_default_awakening
    return unless awakening.nil?

    self.awakening = Awakening.where(slug: 'character-balanced').sole
  end
end