# frozen_string_literal: true

require 'json'

module Granblue
  class ClassicLowerCatalogue
    MANIFEST = Rails.root.join('db/data/manifests/classic_lower_catalogue.json')
    CUTOFF = Date.new(2026, 3, 10)
    LOWER_RARITIES = [1, 2].freeze

    def initialize(manifest: JSON.parse(File.read(MANIFEST)))
      @entries = manifest.fetch('entries')
    end

    def preview
      keys = @entries.map { |entry| [entry.fetch('type'), entry.fetch('granblue_id')] }
      raise 'Duplicate Classic lower identifiers' unless keys.uniq.length == keys.length

      @entries.map do |entry|
        model = { 'Weapon' => Weapon, 'Summon' => Summon }.fetch(entry.fetch('type'))
        rows = model.where(granblue_id: entry.fetch('granblue_id')).to_a
        raise "Expected exactly one #{entry['type']} #{entry['granblue_id']}" unless rows.length == 1

        row = rows.first
        unless LOWER_RARITIES.include?(entry['rarity']) && row.rarity == entry['rarity'] && row.promotions.include?(1)
          raise "Ordinary lower rarity drift #{row.granblue_id}"
        end
        validate_evidence!(row, entry.fetch('evidence'))
        after = (row.promotions + [2, 3, 12]).uniq
        { type: entry['type'], granblue_id: row.granblue_id, id: row.id, before: row.promotions, after: after }
      end
    end

    def apply!
      ActiveRecord::Base.transaction do
        ActiveRecord::Base.connection.execute('LOCK TABLE weapons, summons, characters IN SHARE ROW EXCLUSIVE MODE')
        preview.each do |entry|
          next if entry[:before] == entry[:after]

          entry[:type].constantize.where(id: entry[:id]).update_all(promotions: entry[:after])
        end
      end
    end

    private

    def validate_evidence!(row, evidence)
      bound = Date.iso8601(evidence.fetch('date'))
      raise "Post-cutoff evidence #{row.granblue_id}" unless bound < CUTOFF

      case evidence.fetch('kind')
      when 'catalogue_release_date'
        raise "Release date drift #{row.granblue_id}" unless row.release_date == bound
      when 'recruited_character_release_date'
        raise "Recruitment drift #{row.granblue_id}" unless row.recruits == evidence.fetch('recruits')

        dates = Character.where(granblue_id: row.recruits, rarity: row.rarity, element: row.element, season: nil).pluck(:release_date).uniq
        raise "Character release date drift #{row.granblue_id}" unless dates == [bound]
      when 'wiki_page_existence'
        raise "Missing historical page source #{row.granblue_id}" if evidence.fetch('source').blank?
      else
        raise "Unknown cutoff evidence #{row.granblue_id}"
      end
    end
  end
end
