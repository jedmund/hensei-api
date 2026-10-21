# frozen_string_literal: true

module Granblue
  module Parsers
    module CharacterSkills
      # Applies a character row's curated Japanese skill text (its jp_skill_text source, D38)
      # to a built slot graph, after JpLocalizer: it replaces the JP wiki's text, but never a
      # name or description the game data (game_raw_jp) gave. Mutates the versions in place.
      #
      # Each entry names a slot by kind + position. With an ordinal it sets that version;
      # without one, name_jp goes on every version of the slot and description_jp on the
      # first (the base version).
      class JpSkillText
        FIELDS = %i[name_jp description_jp].freeze

        def initialize(character)
          @character = character
        end

        # The fields the game data already filled, taken before JpLocalizer runs:
        # → { version attrs hash (by identity) => [field, …] }.
        def self.game_fields(slots)
          slots.flat_map { |slot| slot[:versions] }.each_with_object({}.compare_by_identity) do |version, filled|
            filled[version[:attrs]] = FIELDS.select { |field| version[:attrs][field].present? }
          end
        end

        def apply(slots, game_fields:)
          entries = Array(@character.jp_skill_text&.dig('skills'))
          return if entries.empty?

          entries.each do |entry|
            slot = slots.find do |s|
              s[:attrs][:kind] == entry['kind'] && s[:attrs][:position] == entry['position'].to_i
            end
            apply_entry(slot[:versions], entry, game_fields) if slot
          end
        end

        private

        def apply_entry(versions, entry, game_fields)
          targets = if entry['ordinal']
                      versions.select { |v| v[:attrs][:ordinal] == entry['ordinal'].to_i }
                    else
                      versions
                    end
          targets.each_with_index do |version, index|
            set(version[:attrs], :name_jp, entry['name_jp'], game_fields)
            set(version[:attrs], :description_jp, entry['description_jp'], game_fields) if entry['ordinal'] || index.zero?
          end
        end

        def set(attrs, field, value, game_fields)
          return if value.blank? || game_fields.fetch(attrs, []).include?(field)

          attrs[field] = value
        end
      end
    end
  end
end
