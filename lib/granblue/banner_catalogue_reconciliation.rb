# frozen_string_literal: true

require 'json'

module Granblue
  class BannerCatalogueReconciliation
    MANIFEST = Rails.root.join('db/data/manifests/banner_catalogue_reconciliation.json')
    MODELS = { 'Weapon' => Weapon, 'Summon' => Summon }.freeze

    def initialize(manifest: JSON.parse(File.read(MANIFEST)))
      @manifest = manifest
    end

    def preview
      entries = @manifest.fetch('entries')
      keys = entries.map { |entry| [entry.fetch('type'), entry.fetch('granblue_id')] }
      raise 'Duplicate manifest identifiers' unless keys.uniq.length == keys.length

      new_weapons = @manifest.fetch('new_weapons')
      raise 'Duplicate new weapon metadata' unless new_weapons.pluck('granblue_id').uniq.length == new_weapons.length

      metadata = new_weapons.index_by { |entry| entry.fetch('granblue_id') }
      entries.map { |entry| resolve(entry, metadata) }
    end

    def apply!
      ActiveRecord::Base.transaction do
        ActiveRecord::Base.connection.execute('LOCK TABLE weapons, summons, characters IN SHARE ROW EXCLUSIVE MODE')
        preview.each do |entry|
          model = MODELS.fetch(entry.fetch(:type))
          if entry[:action] == 'create'
            model.create!(entry.fetch(:attributes))
          elsif entry[:before] != entry[:after]
            model.where(id: entry.fetch(:id)).update_all(promotions: entry.fetch(:after))
          end
        end
      end
    end

    private

    def resolve(entry, metadata)
      model = MODELS.fetch(entry.fetch('type'))
      rows = model.where(granblue_id: entry.fetch('granblue_id')).to_a
      raise "Duplicate catalogue ID #{entry['granblue_id']}" if rows.length > 1
      if rows.empty? && entry['create']
        return new_weapon(entry, metadata.fetch(entry.fetch('granblue_id')) {
          raise "Missing verified metadata #{entry['granblue_id']}"
        })
      end
      raise "Missing catalogue ID #{entry['granblue_id']}" if rows.empty?

      row = rows.first
      raise "Rarity drift for #{entry['granblue_id']}" unless row.rarity == entry.fetch('rarity')
      validate_metadata!(row, metadata.fetch(entry['granblue_id'])) if entry['create']
      if entry['expected_obtain']
        obtain = row.wiki_raw.to_s[/\|obtain\s*=\s*([^\n]+)/, 1].to_s.strip
        unless obtain == entry['expected_obtain'] && row.recruits == entry['expected_recruits']
          raise "Source drift #{entry['granblue_id']}"
        end
      end
      promotion = entry['add_promotion']
      if entry['rarity'] == 3 && row.promotions.include?(12) && promotion && !row.promotions.include?(1)
        raise "Classic III SSR exclusion conflict #{entry['granblue_id']}"
      end
      after = ((row.promotions - Array(entry['remove_promotions'])) + Array(promotion)).uniq
      after = row.promotions if after.sort == row.promotions.sort
      { type: entry['type'], granblue_id: row.granblue_id, id: row.id, name: row.name_en,
        action: 'update', before: row.promotions, after: after }
    end

    def new_weapon(entry, attributes)
      raise 'Only weapons may be created' unless entry.fetch('type') == 'Weapon'
      validate_attributes!(entry, attributes)
      { type: 'Weapon', granblue_id: entry['granblue_id'], action: 'create', before: [], after: [1],
        attributes: attributes.slice('granblue_id', 'name_en', 'name_jp', 'rarity', 'element', 'proficiency', 'recruits',
                                     'max_level', 'max_skill_level', 'release_date').merge('promotions' => [1], 'gacha' => true) }
    end

    def validate_attributes!(entry, attributes)
      raise "Metadata rarity mismatch #{entry['granblue_id']}" unless attributes.fetch('rarity') == entry.fetch('rarity')
      raise "Missing name #{entry['granblue_id']}" if attributes.fetch('name_en').blank?
      raise "Invalid element #{entry['granblue_id']}" unless (1..6).cover?(attributes.fetch('element'))
      raise "Invalid proficiency #{entry['granblue_id']}" unless (1..10).cover?(attributes.fetch('proficiency'))
      raise "Missing metadata source #{entry['granblue_id']}" if attributes.fetch('source').blank?
      recruits = attributes['recruits']
      if entry.fetch('category').zero?
        raise "Missing recruitment ID #{entry['granblue_id']}" if recruits.blank?
        candidates = Character.where(granblue_id: recruits, rarity: attributes['rarity'], element: attributes['element'],
                                     season: nil).pluck(:granblue_id).uniq
        raise "Recruitment mismatch #{entry['granblue_id']}" unless candidates == [recruits]
      elsif recruits.present?
        raise "Non-character weapon recruits a character #{entry['granblue_id']}"
      end
    end

    def validate_metadata!(row, attributes)
      %w[name_en rarity element proficiency recruits].each do |field|
        raise "Metadata drift #{row.granblue_id}: #{field}" unless row.public_send(field) == attributes[field]
      end
    end
  end
end
