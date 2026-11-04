# frozen_string_literal: true

class CollectionArtifact < ApplicationRecord
  include ArtifactSkillValidations

  # raw_data held the full game payload and nothing read it. It is being cleared
  # (CollectionArtifacts::RawDataClearer) and will be dropped in a later release.
  self.ignored_columns += ['raw_data']

  # Associations
  belongs_to :user
  belongs_to :artifact

  has_many :grid_artifacts, dependent: :nullify

  # prepend: must run before dependent: :nullify clears the foreign key, or it
  # finds no grid items to mark orphaned.
  before_destroy :orphan_grid_items, prepend: true

  enum :element, GranblueEnums::ELEMENT_ENUM

  # Proficiency enum - only used for quirk artifacts (game assigns random proficiency)
  enum :proficiency, GranblueEnums::PROFICIENCY_ENUM

  # Validations
  validates :element, presence: true
  validates :level, presence: true, inclusion: { in: 1..5 }
  validates :nickname, length: { maximum: 50 }, allow_blank: true
  validates :proficiency, presence: true, if: :quirk_artifact?
  validates :proficiency, absence: true, unless: :quirk_artifact?
  validates :reroll_slot, inclusion: { in: 1..4 }, allow_nil: true

  # Scopes
  scope :by_element, ->(el) { where(element: el) }
  scope :by_artifact, ->(artifact_id) { where(artifact_id: artifact_id) }
  # Filter by proficiency - handles both quirk (instance) and standard (artifact) proficiencies.
  # Takes the stored integers or the enum names ('dagger'); other values match nothing.
  scope :by_proficiency, lambda { |prof|
    values = Array(prof).filter_map { |value| proficiency_value(value) }
    joins(:artifact).where(
      'collection_artifacts.proficiency IN (?) OR (collection_artifacts.proficiency IS NULL AND artifacts.proficiency IN (?))',
      values, values
    )
  }
  scope :by_rarity, ->(rar) { joins(:artifact).where(artifacts: { rarity: rar }) }
  scope :standard_only, -> { joins(:artifact).where(artifacts: { rarity: :standard }) }
  scope :quirk_only, -> { joins(:artifact).where(artifacts: { rarity: :quirk }) }
  scope :by_name, lambda { |query|
    joins(:artifact).where('artifacts.name_en ILIKE :q OR artifacts.name_jp ILIKE :q', q: "%#{sanitize_sql_like(query)}%")
  }

  scope :sorted_by, lambda { |sort_key, locale = 'en'|
    name_col = locale == 'ja' ? 'artifacts.name_jp' : 'artifacts.name_en'
    case sort_key
    when 'name_asc'
      joins(:artifact).order(Arel.sql("#{name_col} ASC NULLS LAST"))
    when 'name_desc'
      joins(:artifact).order(Arel.sql("#{name_col} DESC NULLS LAST"))
    when 'element_asc'
      order(element: :asc)
    when 'element_desc'
      order(element: :desc)
    when 'score_desc'
      order(Arel.sql('total_score DESC NULLS LAST'))
    when 'score_asc'
      order(Arel.sql('total_score ASC NULLS LAST'))
    else
      order(created_at: :desc)
    end
  }

  # Filter by skill modifier in a specific slot (1-4)
  # Uses OR logic when multiple modifiers are provided
  scope :with_skill_in_slot, lambda { |slot, modifiers|
    return all if modifiers.blank?

    modifiers = Array(modifiers).map(&:to_s)
    column = "skill#{slot}"

    # Build OR conditions for multiple modifiers
    conditions = modifiers.map { |_| "#{column}->>'modifier' = ?" }.join(' OR ')
    where(conditions, *modifiers)
  }

  # Returns the effective proficiency - from instance for quirk, from artifact for standard
  # A proficiency filter value as its stored integer: digits as they are,
  # an enum name ('dagger', any case) mapped; nil for anything else.
  def self.proficiency_value(value)
    key = value.to_s.strip.downcase
    return proficiencies[key] if proficiencies.key?(key)

    key.to_i if key.match?(/\A\d+\z/)
  end

  def effective_proficiency
    quirk_artifact? ? proficiency : artifact&.proficiency
  end

  private

  def quirk_artifact?
    artifact&.quirk?
  end

  ##
  # Marks all linked grid artifacts as orphaned before destroying this collection artifact.
  #
  # @return [void]
  def orphan_grid_items
    grid_artifacts.update_all(orphaned: true, collection_artifact_id: nil)
  end
end
