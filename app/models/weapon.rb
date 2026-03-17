# frozen_string_literal: true

class Weapon < ApplicationRecord
  include PgSearch::Model

  multisearchable against: %i[name_en name_jp],
                  additional_attributes: lambda { |weapon|
                    {
                      name_en: weapon.name_en,
                      name_jp: weapon.name_jp,
                      granblue_id: weapon.granblue_id,
                      element: weapon.element
                    }
                  }

  pg_search_scope :en_search,
                  against: %i[name_en nicknames_en],
                  using: {
                    tsearch: {
                      prefix: true,
                      dictionary: 'simple'
                    },
                    trigram: {
                      threshold: 0.18
                    }
                  }

  pg_search_scope :ja_search,
                  against: %i[name_jp nicknames_jp],
                  using: {
                    tsearch: {
                      prefix: true,
                      dictionary: 'simple'
                    }
                  }

  has_many :weapon_awakenings
  has_many :awakenings, through: :weapon_awakenings
  has_many :weapon_skills, -> { order(:position) }, primary_key: :granblue_id, foreign_key: :weapon_granblue_id, inverse_of: :weapon
  has_many :skills, through: :weapon_skills
  belongs_to :weapon_series, optional: true
  belongs_to :weapon_series_variant, optional: true
  belongs_to :recruited_character, class_name: 'Character', primary_key: :granblue_id, foreign_key: :recruits, optional: true
  belongs_to :base_weapon, class_name: 'Weapon', primary_key: :granblue_id, foreign_key: :forged_from, optional: true

  def blueprint
    WeaponBlueprint
  end

  def display_resource(weapon)
    weapon.name_en
  end

  def compatible_with_key?(key)
    return false unless weapon_series.present?
    return false unless effective_has_weapon_keys

    key.weapon_series.include?(weapon_series)
  end

  # Returns whether the weapon is included in the Draconic or Dark Opus series
  def opus_or_draconic?
    return false unless weapon_series.present?

    [WeaponSeries::DARK_OPUS, WeaponSeries::DRACONIC].include?(weapon_series.slug)
  end

  # Returns whether the weapon belongs to the Draconic Weapon series or the Draconic Weapon Providence series
  def draconic_or_providence?
    return false unless weapon_series.present?

    [WeaponSeries::DRACONIC, WeaponSeries::DRACONIC_PROVIDENCE].include?(weapon_series.slug)
  end

  def self.element_changeable?(weapon_or_series)
    if weapon_or_series.is_a?(Weapon)
      weapon_or_series.effective_element_changeable
    elsif weapon_or_series.is_a?(WeaponSeries)
      weapon_or_series.element_changeable
    else
      false
    end
  end

  # Variant-aware capability accessors. Returns the variant override if present,
  # otherwise falls back to the weapon series value.
  def effective_has_weapon_keys
    return weapon_series_variant.has_weapon_keys unless weapon_series_variant&.has_weapon_keys.nil?

    weapon_series&.has_weapon_keys || false
  end

  def effective_has_awakening
    return weapon_series_variant.has_awakening unless weapon_series_variant&.has_awakening.nil?

    weapon_series&.has_awakening || false
  end

  def effective_element_changeable
    return weapon_series_variant.element_changeable unless weapon_series_variant&.element_changeable.nil?

    weapon_series&.element_changeable || false
  end

  def effective_extra
    return weapon_series_variant.extra unless weapon_series_variant&.extra.nil?

    weapon_series&.extra || false
  end

  def effective_num_weapon_keys
    return weapon_series_variant.num_weapon_keys unless weapon_series_variant&.num_weapon_keys.nil?

    weapon_series&.num_weapon_keys
  end

  def effective_augment_type
    return weapon_series_variant.augment_type unless weapon_series_variant&.augment_type.nil?

    weapon_series&.augment_type || 'no_augment'
  end

  # Promotion scopes
  scope :by_promotion, ->(promotion) { where('? = ANY(promotions)', promotion) }
  scope :in_premium, -> { by_promotion(GranblueEnums::PROMOTIONS[:Premium]) }
  scope :in_classic, -> { by_promotion(GranblueEnums::PROMOTIONS[:Classic]) }
  scope :flash_exclusive, -> { by_promotion(GranblueEnums::PROMOTIONS[:Flash]).where.not('? = ANY(promotions)', GranblueEnums::PROMOTIONS[:Legend]) }
  scope :legend_exclusive, -> { by_promotion(GranblueEnums::PROMOTIONS[:Legend]).where.not('? = ANY(promotions)', GranblueEnums::PROMOTIONS[:Flash]) }

  # Forge chain scopes
  scope :in_forge_chain, ->(chain_id) { where(forge_chain_id: chain_id).order(:forge_order) }

  # Forge chain callbacks
  before_save :compute_forge_chain_fields, if: :forged_from_changed?

  # Forge chain methods
  def forged_from_weapon
    return nil unless forged_from.present?

    Weapon.find_by(granblue_id: forged_from)
  end

  def forge_chain(same_element: true)
    return [] unless forge_chain_id.present?

    chain = Weapon.in_forge_chain(forge_chain_id)
    same_element ? chain.where(element: element) : chain
  end

  def forges_to(same_element: true)
    weapons = Weapon.where(forged_from: granblue_id)
    same_element ? weapons.where(element: element) : weapons
  end

  # Promotion helpers
  def flash?
    promotions.include?(GranblueEnums::PROMOTIONS[:Flash])
  end

  def legend?
    promotions.include?(GranblueEnums::PROMOTIONS[:Legend])
  end

  def premium?
    promotions.include?(GranblueEnums::PROMOTIONS[:Premium])
  end

  def promotion_names
    promotions.filter_map { |p| GranblueEnums::PROMOTIONS.key(p)&.to_s }
  end

  def series_slug
    weapon_series&.slug
  end

  # Virtual attribute to set weapon_series by ID or slug
  # Supports both UUID and slug lookup for flexibility
  def series=(value)
    return self.weapon_series = nil if value.blank?

    # Try to find by ID first, then by slug
    found = WeaponSeries.find_by(id: value) || WeaponSeries.find_by(slug: value)
    self.weapon_series = found
  end

  # Validation to prevent circular forge chains
  validate :no_circular_forge_chain

  def no_circular_forge_chain
    return unless forged_from.present?

    visited = Set.new([granblue_id])
    current = forged_from

    while current.present?
      if visited.include?(current)
        errors.add(:forged_from, 'creates a circular forge chain')
        return
      end
      visited << current
      current = Weapon.find_by(granblue_id: current)&.forged_from
    end
  end

  private

  # Auto-compute forge_order and forge_chain_id based on forged_from
  # Walks the full chain to the root to ensure correct ordering
  def compute_forge_chain_fields
    if forged_from.present?
      # Walk up the chain to find the root and count depth
      chain = []
      current = Weapon.find_by(granblue_id: forged_from)
      return unless current

      visited = Set.new([granblue_id])
      while current
        break if visited.include?(current.granblue_id)
        chain.unshift(current)
        visited.add(current.granblue_id)

        if current.forged_from.present?
          current = Weapon.find_by(granblue_id: current.forged_from)
        else
          break
        end
      end

      # First element is the root
      root = chain.first
      root_chain_id = root.forge_chain_id || root.id
      self.forge_chain_id = root_chain_id
      self.forge_order = chain.length

      # Fix up the entire chain: root and all intermediates
      chain.each_with_index do |weapon, index|
        updates = {}
        updates[:forge_chain_id] = root_chain_id if weapon.forge_chain_id != root_chain_id
        updates[:forge_order] = index if weapon.forge_order != index
        weapon.update_columns(updates) if updates.any?
      end
    else
      # Clearing forged_from - reset forge_order if part of a chain
      self.forge_order = 0 if forge_chain_id.present?
    end
  end
end
