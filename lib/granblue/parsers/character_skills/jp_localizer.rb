# frozen_string_literal: true

module Granblue
  module Parsers
    module CharacterSkills
      # Fills name_jp/description_jp on a built slot graph from the cached Japanese
      # wiki (wiki_raw_jp), aligned to the EN slots by position. No-op when JP HTML
      # is absent. Mutates the slot versions in place.
      class JpLocalizer
        # Variant roles whose JP text comes from a transform row, not the base skill.
        STATE_VARIANT_ROLES = %w[transform_alt form_alt option].freeze

        def initialize(character)
          @character = character
        end

        def apply(slots)
          return if @character.wiki_raw_jp.blank?

          jp = JpWikiSkillParser.new(@character).parse
          ability_groups = group_jp_abilities(jp[:abilities])

          slots.each do |slot|
            case slot[:attrs][:kind]
            when 'ability'
              localize_slot(slot, ability_groups[slot[:attrs][:position] - 1])
            when 'ougi'
              slot[:versions].each_with_index { |version, index| set_jp(version, jp[:ougi][index]) }
            when 'support'
              entry = jp[:support][slot[:attrs][:position] - 1]
              slot[:versions].each { |version| set_jp(version, entry) }
            end
          end
        end

        private

        # JP abilities are a flat list where transform/option rows follow their
        # base. A cooldown-bearing row starts a new slot group; the rest attach.
        def group_jp_abilities(abilities)
          abilities.each_with_object([]) do |entry, groups|
            if groups.empty? || entry.key?(:cooldown)
              groups << [entry]
            else
              groups.last << entry
            end
          end
        end

        def localize_slot(slot, group)
          return if group.blank?

          base = group.first
          transforms = group.drop(1)
          slot[:versions].each do |version|
            alt = transforms.shift if STATE_VARIANT_ROLES.include?(version[:attrs][:variant_role])
            set_jp(version, alt || base)
          end
        end

        def set_jp(version, jp_entry)
          return if jp_entry.blank?

          version[:attrs][:name_jp] ||= jp_entry[:name_jp].presence
          version[:attrs][:description_jp] ||= jp_entry[:effect_jp].to_s.gsub(/\s+/, ' ').strip.presence
        end
      end
    end
  end
end
