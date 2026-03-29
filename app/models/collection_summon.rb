class CollectionSummon < ApplicationRecord
  belongs_to :user
  belongs_to :summon

  has_many :grid_summons, dependent: :nullify

  before_destroy :orphan_grid_items

  validates :uncap_level, inclusion: { in: 0..6 }
  validates :transcendence_step, inclusion: { in: 0..10 }

  validate :validate_transcendence_requirements

  scope :by_summon, ->(summon_id) { where(summon_id: summon_id) }
  scope :by_element, ->(element) { joins(:summon).where(summons: { element: element }) }
  scope :by_rarity, ->(rarity) { joins(:summon).where(summons: { rarity: rarity }) }
  scope :by_series, ->(series_id) { joins(:summon).where(summons: { summon_series_id: series_id }) }
  scope :transcended, -> { where('transcendence_step > 0') }
  scope :max_uncapped, -> { where(uncap_level: 5) }
  scope :by_name, ->(query) {
    joins(:summon).where("summons.name_en ILIKE :q OR summons.name_jp ILIKE :q", q: "%#{sanitize_sql_like(query)}%")
  }

  scope :sorted_by, ->(sort_key, locale = 'en') {
    name_col = locale == 'ja' ? 'summons.name_jp' : 'summons.name_en'
    case sort_key
    when 'name_asc'
      joins(:summon).order(Arel.sql("#{name_col} ASC NULLS LAST"))
    when 'name_desc'
      joins(:summon).order(Arel.sql("#{name_col} DESC NULLS LAST"))
    when 'element_asc'
      joins(:summon).order('summons.element ASC')
    when 'element_desc'
      joins(:summon).order('summons.element DESC')
    else
      order(created_at: :desc)
    end
  }

  def blueprint
    Api::V1::CollectionSummonBlueprint
  end

  private

  def validate_transcendence_requirements
    return unless transcendence_step.present? && transcendence_step > 0

    if uncap_level < 5
      errors.add(:transcendence_step, "requires uncap level 5 (current: #{uncap_level})")
    end

    # Some summons might not support transcendence
    if summon.present? && !summon.transcendence
      errors.add(:transcendence_step, "not available for this summon")
    end
  end

  ##
  # Marks all linked grid summons as orphaned before destroying this collection summon.
  #
  # @return [void]
  def orphan_grid_items
    grid_summons.update_all(orphaned: true, collection_summon_id: nil)
  end
end