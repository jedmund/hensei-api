# frozen_string_literal: true

module Granblue
  module Parsers
    module CharacterSkills
      # Fills name_jp/description_jp on a built slot graph from the cached Japanese
      # wiki (wiki_raw_jp), aligned to the EN slots by position. No-op when JP HTML
      # is absent. Mutates the slot versions in place.
      #
      # A style shift shares its base's JP page, where its skills sit in their own
      # スタイルシフト「…」 section. The base row reads the page without those sections and
      # the style row reads only its own; a style row whose page has no such section gets
      # no JP text rather than the base's.
      class JpLocalizer
        # Variant roles whose JP text comes from a transform row, not the base skill.
        STATE_VARIANT_ROLES = %w[transform_alt form_alt option].freeze
        STYLE_HEADING = /\Aスタイルシフト「/
        SECTION_HEADINGS = %w[h2 h3].freeze

        # The slice of the page a row reads, in the shape JpWikiSkillParser expects.
        Page = Struct.new(:wiki_raw_jp)

        def initialize(character)
          @character = character
        end

        def apply(slots)
          return if @character.wiki_raw_jp.blank?

          page = own_page
          return if page.nil?

          jp = JpWikiSkillParser.new(page).parse
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

        def own_page
          document = Nokogiri::HTML(@character.wiki_raw_jp)
          body = document.at_css('div#body')
          sections = body ? style_sections(body) : {}
          return style_page(sections) if @character.style_swap

          return Page.new(@character.wiki_raw_jp) if sections.empty?

          sections.each_value { |nodes| nodes.each(&:remove) }
          Page.new(document.to_html)
        end

        # Prefers the section named after this style; falls back to every style section.
        def style_page(sections)
          named = sections.select { |heading, _| heading.include?("「#{@character.style_name_jp}」") }
          nodes = (@character.style_name_jp.present? && named.any? ? named : sections).values.flatten
          return if nodes.empty?

          Page.new("<div id=\"body\">#{nodes.map(&:to_html).join}</div>")
        end

        # { heading text => [heading, following siblings up to the next h2/h3] } for each
        # スタイルシフト「…」 heading. A voice-line section of the same name holds no skill
        # tables, so the parser ignores it.
        def style_sections(body)
          body.element_children.each_with_object({}) do |node, sections|
            next unless SECTION_HEADINGS.include?(node.name) && node.text.strip.match?(STYLE_HEADING)

            nodes = [node]
            sibling = node.next_element
            until sibling.nil? || SECTION_HEADINGS.include?(sibling.name)
              nodes << sibling
              sibling = sibling.next_element
            end
            (sections[node.text.strip] ||= []).concat(nodes)
          end
        end

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
