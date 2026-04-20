# frozen_string_literal: true

module CollectionImport
  ##
  # Formats an ActiveRecord::Dirty changes hash into user-visible deltas.
  # Used by the preview_updates methods on the collection import services to
  # return diffs the extension can render in a tooltip.
  #
  # Output shape per change:
  #   {
  #     field: 'uncap_level',
  #     label: 'Uncap',
  #     before: { raw: 4, display: '4' },
  #     after:  { raw: 5, display: '5' }
  #   }
  module ChangeFormatter
    FIELD_LABELS = {
      'uncap_level'            => 'Uncap',
      'transcendence_step'     => 'Transcendence',
      'awakening_id'           => 'Awakening',
      'awakening_level'        => 'Awakening Level',
      'element'                => 'Element',
      'exorcism_level'         => 'Exorcism',
      'befoulment_modifier_id' => 'Befoulment',
      'befoulment_strength'    => 'Befoulment Strength',
      'ax_modifier1_id'        => 'AX Skill 1',
      'ax_strength1'           => 'AX Skill 1 Strength',
      'ax_modifier2_id'        => 'AX Skill 2',
      'ax_strength2'           => 'AX Skill 2 Strength',
      'weapon_key1_id'         => 'Weapon Key 1',
      'weapon_key2_id'         => 'Weapon Key 2',
      'weapon_key3_id'         => 'Weapon Key 3',
      'weapon_key4_id'         => 'Weapon Key 4',
      'perpetuity'             => 'Perpetuity Ring',
      'ring1'                  => 'Ring 1',
      'ring2'                  => 'Ring 2',
      'ring3'                  => 'Ring 3',
      'ring4'                  => 'Ring 4',
      'earring'                => 'Earring'
    }.freeze

    # Internal element IDs: 0=Null, 1=Wind, 2=Fire, 3=Water, 4=Earth, 5=Dark, 6=Light
    # (See GranblueEnums::ELEMENTS.)
    INTERNAL_ELEMENT_NAMES = {
      0 => 'Null', 1 => 'Wind', 2 => 'Fire', 3 => 'Water',
      4 => 'Earth', 5 => 'Dark', 6 => 'Light'
    }.freeze

    module_function

    # @param changes [Hash] an ActiveRecord::Dirty changes hash
    # @return [Array<Hash>] formatted change entries
    def format(changes)
      changes.map do |field, (before, after)|
        {
          field: field,
          label: FIELD_LABELS[field] || field.humanize,
          before: format_value(field, before),
          after: format_value(field, after)
        }
      end
    end

    def format_value(field, value)
      { raw: value, display: display_for(field, value) }
    end

    def display_for(field, value)
      return '—' if value.nil?

      case field
      when 'awakening_id'
        resolve_awakening(value)
      when /\Aweapon_key\d_id\z/
        resolve_weapon_key(value)
      when /\Aax_modifier\d_id\z/, 'befoulment_modifier_id'
        resolve_stat_modifier(value)
      when 'element'
        INTERNAL_ELEMENT_NAMES[value.to_i] || value.to_s
      when 'perpetuity'
        value ? 'Yes' : 'No'
      when /\Aring\d\z/, 'earring'
        format_ring(value)
      else
        value.to_s
      end
    end

    def resolve_awakening(id)
      return '—' if id.blank?

      Awakening.find_by(id: id)&.name_en || id.to_s
    end

    def resolve_weapon_key(id)
      return '—' if id.blank?

      WeaponKey.find_by(id: id)&.name_en || id.to_s
    end

    def resolve_stat_modifier(id)
      return '—' if id.blank?

      WeaponStatModifier.find_by(id: id)&.name_en || id.to_s
    end

    # Rings are jsonb { 'modifier' => Integer, 'strength' => Integer }. Modifier
    # indexes into the client-side overMastery/aetherialMastery catalogs, so we
    # don't have a server-side name for it — render as "mod N, str M".
    def format_ring(ring)
      return 'None' unless ring.is_a?(Hash)
      return 'None' if ring['modifier'].blank? || ring['modifier'].to_i.zero?

      "mod #{ring['modifier']}, str #{ring['strength']}"
    end
  end
end
