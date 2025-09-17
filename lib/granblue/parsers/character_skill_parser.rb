# frozen_string_literal: true

module Granblue
  module Parsers
    class CharacterSkillParser
      require 'nokogiri'

      def initialize(character)
        @character = character
        @wiki_data = begin
          # Don't try to parse as JSON - parse as MediaWiki format instead
          extract_wiki_data(@character.wiki_raw)
        rescue StandardError => e
          Rails.logger.error "Error parsing wiki raw data: #{e.message}"
          nil
        end
        @game_data = @character.game_raw_en
      end

      def extract_wiki_data(wikitext)
        return nil unless wikitext.present?

        data = {}
        # Extract basic character info from template
        wikitext.scan(/\|(\w+)=([^\n|]+)/) do |key, value|
          data[key] = value.strip
        end

        # Extract ability count
        if match = wikitext.match(/\|abilitycount=\s*(\d+)/)
          data['abilitycount'] = match[1]
        end

        # Extract individual abilities
        skill_count = data['abilitycount'].to_i
        (1..skill_count).each do |position|
          # Extract ability icon, name, cooldown, etc.
          extract_skill_data(wikitext, position, data)
        end

        # Extract charge attack data
        extract_ougi_data(wikitext, data)

        data
      end

      def extract_skill_data(wikitext, position, data)
        prefix = "a#{position}"

        # Extract skill name
        if match = wikitext.match(/\|#{prefix}_name=\s*([^\n|]+)/)
          data["#{prefix}_name"] = match[1].strip
        end

        # Extract skill cooldown
        if match = wikitext.match(/\|#{prefix}_cd=\s*\{\{InfoCd[^}]*cooldown=(\d+)[^}]*\}\}/)
          data["#{prefix}_cd"] = match[1]
        end

        # Extract skill description using InfoDes template
        if match = wikitext.match(/\|#{prefix}_effdesc=\s*\{\{InfoDes\|num=\d+\|des=([^|]+)(?:\|[^}]+)?\}\}/)
          data["#{prefix}_effdesc"] = match[1].strip
        end

        # Check for alt version indicator
        data["#{prefix}_option"] = 'alt' if wikitext.match(/\|#{prefix}_option=alt/)

        # Extract obtained level
        if (match = wikitext.match(/\|#{prefix}_oblevel=\s*\{\{InfoOb\|obtained=(\d+)(?:\|[^}]+)?\}\}/))
          data["#{prefix}_oblevel"] = "obtained=#{match[1]}"
        end

        # Extract enhanced level if present
        if (match = wikitext.match(/\|#{prefix}_oblevel=\s*\{\{InfoOb\|obtained=\d+\|enhanced=(\d+)(?:\|[^}]+)?\}\}/))
          data["#{prefix}_oblevel"] += "|enhanced=#{match[1]}"
        end
      end

      def extract_ougi_data(wikitext, data)
        # Extract charge attack name
        if (match = wikitext.match(/\|ougi_name=\s*([^\n|]+)/))
          data['ougi_name'] = match[1].strip
        end

        # Extract charge attack description
        if (match = wikitext.match(/\|ougi_desc=\s*([^\n|]+)/))
          data['ougi_desc'] = match[1].strip
        end

        # Extract FLB/ULB charge attack details if present
        if (match = wikitext.match(/\|ougi2_name=\s*([^\n|]+)/))
          data['ougi2_name'] = match[1].strip
        end

        return unless (match = wikitext.match(/\|ougi2_desc=\s*([^\n|]+)/))

        data['ougi2_desc'] = match[1].strip
      end

      def parse_and_save
        return unless @wiki_data && @game_data

        # Parse and save skills
        parse_skills

        # Parse and save charge attack
        parse_charge_attack

        # Return success status
        true
      rescue StandardError => e
        Rails.logger.error "Error parsing skills for character #{@character.name_en}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        false
      end

      private

      def parse_skills
        # Get ability data from game data
        game_abilities = @game_data['ability'] || {}
        ap 'Game'
        ap game_abilities

        # Get skill count from wiki data
        skill_count = @wiki_data['abilitycount'].to_i
        ap 'Wiki'
        ap skill_count

        # Process each skill
        (1..skill_count).each do |position|
          game_skill = game_abilities[position.to_s]
          next unless game_skill

          # Create or find skill
          skill = Skill.find_or_initialize_by(
            name_en: game_skill['name_en'] || game_skill['name'],
            skill_type: Skill.skill_types[:character]
          )

          # Set skill attributes
          skill.name_jp = game_skill['name'] if game_skill['name'].present?
          skill.description_en = game_skill['comment_en'] || game_skill['comment']
          skill.description_jp = game_skill['comment'] if game_skill['comment'].present?
          skill.border_type = extract_border_type(game_skill)
          skill.cooldown = game_skill['recast'].to_i if game_skill['recast'].present?

          # Save skill
          skill.save!

          # Wiki data for skill
          wiki_skill_key = "a#{position}"
          wiki_skill = @wiki_data[wiki_skill_key] || {}

          # Create character skill connection
          character_skill = CharacterSkill.find_or_initialize_by(
            character_granblue_id: @character.granblue_id,
            position: position
          )

          character_skill.skill = skill
          character_skill.unlock_level = wiki_skill["a#{position}_oblevel"]&.match(/obtained=(\d+)/)&.captures&.first&.to_i || 1
          character_skill.improve_level = wiki_skill["a#{position}_oblevel"]&.match(/enhanced=(\d+)/)&.captures&.first&.to_i

          # Check for alt version
          if game_skill['display_action_ability_info']&.dig('action_ability')&.any?
            # Handle alt version of skill
            alt_action = game_skill['display_action_ability_info']['action_ability'].first

            alt_skill = Skill.find_or_initialize_by(
              name_en: alt_action['name_en'] || alt_action['name'],
              skill_type: Skill.skill_types[:character]
            )

            alt_skill.name_jp = alt_action['name'] if alt_action['name'].present?
            alt_skill.description_en = alt_action['comment_en'] || alt_action['comment']
            alt_skill.description_jp = alt_action['comment'] if alt_action['comment'].present?
            alt_skill.border_type = extract_border_type(alt_action)
            alt_skill.cooldown = alt_action['recast'].to_i if alt_action['recast'].present?

            alt_skill.save!

            character_skill.alt_skill = alt_skill

            # Parse condition for alt version
            if wiki_skill['alt_condition'].present?
              character_skill.alt_condition = wiki_skill['alt_condition']
            elsif game_skill['comment_en']&.include?('when')
              # Try to extract condition from comment
              if match = game_skill['comment_en'].match(/\(.*?when\s+(.*?)\s*(?::|$)/i)
                character_skill.alt_condition = match[1]
              end
            end
          end

          character_skill.save!

          # Parse and save effects
          parse_effects_for_skill(skill, game_skill)

          # If alt skill exists, parse its effects too
          if character_skill.alt_skill
            alt_action = game_skill['display_action_ability_info']['action_ability'].first
            parse_effects_for_skill(character_skill.alt_skill, alt_action)
          end
        end
      end

      def parse_charge_attack
        ap 'Parsing charge attack...'
        # Get charge attack data from wiki and game
        wiki_ougi = {
          'name' => @wiki_data['ougi_name'],
          'desc' => @wiki_data['ougi_desc']
        }

        # ap @game_data
        game_ougi = @game_data['special_skill']
        ap 'Game ougi:'
        ap game_ougi
        return unless game_ougi

        puts 'Wiki'
        puts wiki_ougi
        puts 'Game'
        puts game_ougi

        # Create skill for charge attack
        skill = Skill.find_or_initialize_by(
          name_en: wiki_ougi['name'] || game_ougi['name'],
          skill_type: Skill.skill_types[:charge_attack]
        )

        skill.name_jp = game_ougi['name'] if game_ougi['name'].present?
        skill.description_en = wiki_ougi['desc'] || game_ougi['comment']
        skill.description_jp = game_ougi['comment'] if game_ougi['comment'].present?
        skill.save!

        # Create charge attack record
        charge_attack = ChargeAttack.find_or_initialize_by(
          owner_id: @character.granblue_id,
          owner_type: 'character',
          uncap_level: 0
        )

        charge_attack.skill = skill
        charge_attack.save!

        # Parse effects for charge attack
        parse_effects_for_charge_attack(skill, wiki_ougi['desc'], game_ougi)

        # If there are uncapped charge attacks
        return unless @wiki_data['ougi2_name'].present?

        # Process 5* uncap charge attack
        alt_skill = Skill.find_or_initialize_by(
          name_en: @wiki_data['ougi2_name'],
          skill_type: Skill.skill_types[:charge_attack]
        )

        alt_skill.description_en = @wiki_data['ougi2_desc']
        alt_skill.save!

        # Create alt charge attack record
        alt_charge_attack = ChargeAttack.find_or_initialize_by(
          owner_id: @character.granblue_id,
          owner_type: 'character',
          uncap_level: 4 # 5* uncap
        )

        alt_charge_attack.skill = alt_skill
        alt_charge_attack.save!

        # Parse effects for alt charge attack
        parse_effects_for_charge_attack(alt_skill, @wiki_data['ougi2_desc'], nil)
      end

      def parse_effects_for_skill(skill, game_skill)
        # Look for buff/debuff details
        if game_skill['ability_detail'].present?
          # Process buffs
          if game_skill['ability_detail']['buff'].present?
            game_skill['ability_detail']['buff'].each do |buff_data|
              create_effect_from_game_data(skill, buff_data, :buff)
            end
          end

          # Process debuffs
          if game_skill['ability_detail']['debuff'].present?
            game_skill['ability_detail']['debuff'].each do |debuff_data|
              create_effect_from_game_data(skill, debuff_data, :debuff)
            end
          end
        end

        # Also try to extract effects from description
        extract_effects_from_description(skill, game_skill['comment_en'] || game_skill['comment'])
      end

      def parse_effects_for_charge_attack(skill, description, game_ougi)
        # Extract effects from charge attack description
        extract_effects_from_description(skill, description)

        # If we have game data, try to extract more details
        return unless game_ougi && game_ougi['comment'].present?

        extract_effects_from_description(skill, game_ougi['comment'])
      end

      def create_effect_from_game_data(skill, effect_data, effect_type)
        # Extract effect name and status code
        status = effect_data['status']
        detail = effect_data['detail']
        effect_duration = effect_data['effect']

        # Get effect class (normalized type) from the detail
        effect_class = normalize_effect_class(detail)

        # Create or find effect
        effect = Effect.find_or_initialize_by(
          name_en: detail,
          effect_type: Effect.effect_types[effect_type]
        )

        effect.effect_class = effect_class
        effect.save!

        # Create skill effect connection
        skill_effect = SkillEffect.find_or_initialize_by(
          skill: skill,
          effect: effect
        )

        # Figure out target type
        target_type = determine_target_type(skill, detail)
        skill_effect.target_type = target_type

        # Figure out duration
        duration_info = parse_duration(effect_duration)
        skill_effect.duration_type = duration_info[:type]
        skill_effect.duration_value = duration_info[:value]

        # Other attributes
        skill_effect.value = extract_value_from_detail(detail)
        skill_effect.cap = extract_cap_from_detail(detail)
        skill_effect.permanent = effect_duration.blank? || effect_duration.downcase == 'permanent'
        skill_effect.undispellable = detail.include?("Can't be removed")

        skill_effect.save!
      end

      def extract_effects_from_description(skill, description)
        return unless description.present?

        # Look for status effects in the description with complex pattern matching
        status_pattern = /\{\{status\|([^|}]+)(?:\|([^}]+))?\}\}/

        description.scan(status_pattern).each do |matches|
          status_name = matches[0].strip
          attrs_text = matches[1]

          # Create effect
          effect = Effect.find_or_initialize_by(
            name_en: status_name,
            effect_type: determine_effect_type(status_name)
          )

          effect.effect_class = normalize_effect_class(status_name)
          effect.save!

          # Create skill effect with attributes
          skill_effect = SkillEffect.find_or_initialize_by(
            skill: skill,
            effect: effect
          )

          # Parse attributes from the status tag
          if attrs_text.present?
            attrs = {}

            # Extract duration (t=X)
            if duration_match = attrs_text.match(/t=([^|]+)/)
              attrs[:duration] = duration_match[1]
            end

            # Extract value (a=X)
            if value_match = attrs_text.match(/a=([^|%]+)/)
              attrs[:value] = value_match[1]
            end

            # Extract cap
            if cap_match = attrs_text.match(/cap=(\d+)/)
              attrs[:cap] = cap_match[1]
            end

            # Apply extracted attributes
            skill_effect.target_type = determine_target_type(skill, status_name)
            skill_effect.value = attrs[:value].to_f if attrs[:value].present?
            skill_effect.cap = attrs[:cap].to_i if attrs[:cap].present?

            # Parse duration
            if attrs[:duration].present?
              duration_info = parse_duration(attrs[:duration])
              skill_effect.duration_type = duration_info[:type]
              skill_effect.duration_value = duration_info[:value]
            end

            skill_effect.undispellable = attrs_text.include?("can't be removed")
          end

          skill_effect.save!
        end
      end

      def extract_border_type(skill_data)
        # Map class_name to border type
        class_name = skill_data['class_name']

        if class_name.nil?
          nil
        elsif class_name.end_with?('_1')
          Skill.border_types[:damage]
        elsif class_name.end_with?('_2')
          Skill.border_types[:healing]
        elsif class_name.end_with?('_3')
          Skill.border_types[:buff]
        elsif class_name.end_with?('_4')
          Skill.border_types[:debuff]
        elsif class_name.end_with?('_5')
          Skill.border_types[:field]
        else
          nil
        end
      end

      def normalize_effect_class(detail)
        # Map common effect descriptions to standardized classes
        return nil unless detail.present?

        detail = detail.downcase

        if detail.include?("can't attack") || detail.include?("can't act") || detail.include?('actions for') || detail.include?('actions are sealed')
          'cant_act'
        elsif detail.include?('hp is lowered on every turn') && !detail.include?('putrefied')
          'poison'
        elsif detail.include?('putrefied') || detail.include?('hp is lowered on every turn based on')
          'poison_strong'
        elsif detail.include?('atk is boosted based on how low hp is') || detail.include?('jammed')
          'jammed'
        elsif detail.include?('veil') || detail.include?('debuffs will be nullified')
          'veil'
        elsif detail.include?('mirror') || detail.include?('next attack will miss')
          'mirror_image'
        elsif detail.match?(/dodge.+hit|taking less dmg/i)
          'repel'
        elsif detail.include?('shield') || detail.include?('ineffective for a fixed amount')
          'shield'
        elsif detail.include?('counter') && detail.include?('dodge')
          'counter_on_dodge'
        elsif detail.include?('counter') && detail.include?('dmg')
          'counter_on_damage'
        elsif detail.include?('boost to triple attack') || detail.include?('triple attack rate')
          'ta_up'
        elsif detail.include?('boost to double attack') || detail.include?('double attack rate')
          'da_up'
        elsif detail.include?('boost to charge bar') || detail.include?('charge boost')
          'charge_bar_boost'
        elsif detail.include?('drain') || detail.include?('absorbed to hp')
          'drain'
        elsif detail.include?('bonus') && detail.include?('dmg')
          'echo'
        elsif detail.match?(/atk is (?:sharply )?boosted/i) && !detail.include?('based on')
          'atk_up'
        elsif detail.match?(/def is (?:sharply )?boosted/i) && !detail.include?('based on')
          'def_up'
        else
          # Create a slug from the first few words
          detail.split(/\s+/).first(3).join('_').gsub(/[^a-z0-9_]/i, '').downcase
        end
      end

      def determine_effect_type(name)
        name = name.downcase

        if name.include?('down') || name.include?('lower') || name.include?('hit') || name.include?('reduced') ||
           name.include?('blind') || name.include?('petrif') || name.include?('paralyze') || name.include?('stun') ||
           name.include?('charm') || name.include?('poison') || name.include?('putrefied') || name.include?('sleep') ||
           name.include?('fear') || name.include?('delay')
          Effect.effect_types[:debuff]
        else
          Effect.effect_types[:buff]
        end
      end

      def determine_target_type(skill, detail)
        # Try to determine target type from skill and detail
        if detail.downcase.include?('all allies')
          SkillEffect.target_types[:all_allies]
        elsif detail.downcase.include?('all foes')
          SkillEffect.target_types[:all_enemies]
        elsif detail.downcase.include?('caster') || detail.downcase.include?('own ')
          SkillEffect.target_types[:self]
        elsif skill.border_type == Skill.border_types[:buff] || detail.downcase.include?('allies') || detail.downcase.include?('party')
          SkillEffect.target_types[:ally]
        elsif skill.border_type == Skill.border_types[:debuff] || detail.downcase.include?('foe') || detail.downcase.include?('enemy')
          SkillEffect.target_types[:enemy]
        elsif determine_effect_type(detail) == Effect.effect_types[:buff]
          # Default
          SkillEffect.target_types[:self]
        else
          SkillEffect.target_types[:enemy]
        end
      end

      def parse_duration(duration_text)
        return { type: SkillEffect.duration_types[:indefinite], value: nil } unless duration_text.present?

        duration_text = duration_text.downcase

        if duration_text.include?('turn')
          # Parse turns
          turns = duration_text.scan(/(\d+(?:\.\d+)?)(?:\s*-)?\s*turn/).flatten.first
          {
            type: SkillEffect.duration_types[:turns],
            value: turns.to_f
          }
        elsif duration_text.include?('sec')
          # Parse seconds
          seconds = duration_text.scan(/(\d+)(?:\s*-)?\s*sec/).flatten.first
          {
            type: SkillEffect.duration_types[:seconds],
            value: seconds.to_i
          }
        elsif duration_text.include?('time') || duration_text.include?('hit')
          # Parse one-time
          { type: SkillEffect.duration_types[:one_time], value: nil }
        else
          # Default to indefinite
          { type: SkillEffect.duration_types[:indefinite], value: nil }
        end
      end

      def parse_status_attributes(attr_string)
        result = {
          value: nil,
          cap: nil,
          duration: nil,
          chance: 100, # Default
          options: []
        }

        # Split attributes
        attrs = attr_string.split('|')

        attrs.each do |attr|
          if attr.include?('=')
            key, value = attr.split('=', 2)
            key = key.strip
            value = value.strip

            case key
            when 'a'
              # Value (amount)
              result[:value] = if value.end_with?('%')
                                 value.delete('%').to_f
                               else
                                 value
                               end
            when 'cap'
              # Cap
              result[:cap] = value.gsub(/[^\d]/, '').to_i
            when 't'
              # Duration
              result[:duration] = value
            when 'acc'
              # Accuracy
              result[:chance] = if value == 'Guaranteed'
                                  100
                                else
                                  value.delete('%').to_i
                                end
            else
              # Other options
              result[:options] << "#{key}=#{value}"
            end
          elsif attr == 'i'
            # Simple attributes like "n=1" or just "i"
            result[:duration] = 'indefinite'
          elsif attr.start_with?('n=')
            # Number of hits/times
            # Store in options
            result[:options] << attr.strip
          else
            result[:options] << attr.strip
          end
        end

        result
      end

      def extract_value_from_detail(detail)
        # Extract numeric value from detail text
        if match = detail.match(/(\d+(?:\.\d+)?)%/)
          match[1].to_f
        else
          nil
        end
      end

      def extract_cap_from_detail(detail)
        # Extract cap from detail text
        if match = detail.match(/cap(?:ped)?\s*(?:at|:)\s*(\d+(?:,\d+)*)/)
          match[1].gsub(',', '').to_i
        else
          nil
        end
      end
    end
  end
end
