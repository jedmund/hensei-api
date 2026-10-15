# frozen_string_literal: true

module WeaponSkills
  module Build
    # The curation overlay's structural ops on a weapon's compiled versions, in the overlay's
    # order (overlay-v2.md): remove_version, add_version, gate, description. An op names a
    # version by [skill name, ordinal]; one that matches nothing is skipped (the sync reports
    # unmatched ops). Pure: returns new Versions, never mutates.
    module StructuralOps
      Version = WeaponSkills::BuildResult::Version
      GATE_FIELDS = %w[unlock_level min_uncap transcendence_stage].freeze
      DESCRIPTION_FIELDS = %w[description_en description_jp].freeze

      module_function

      # → [Version]
      def apply(weapon_granblue_id, versions, ops)
        by_identity = versions.to_h { |v| [v.identity, v.dup] }
        find = ->(op) { by_identity.values.find { |v| v.skill_name_en == op["skill"] && v.ordinal == op["ordinal"] } }

        ops.select { |op| op["op"] == "remove_version" }.each do |op|
          version = find.call(op) or next
          by_identity.delete(version.identity)
        end
        ops.select { |op| op["op"] == "add_version" }.each do |op|
          next if find.call(op)

          identity = [weapon_granblue_id, op["position"], op["ordinal"]]
          next if by_identity.key?(identity)

          by_identity[identity] = Version.new(
            weapon_granblue_id: weapon_granblue_id, position: op["position"], ordinal: op["ordinal"],
            skill_name_en: op["skill"], skill_name_jp: op["skill_jp"],
            description_en: op["description_en"], description_jp: op["description_jp"],
            unlock_level: op["unlock_level"], min_uncap: op["min_uncap"],
            transcendence_stage: op["transcendence_stage"] || 0, icon: op["icon"]
          )
        end
        ops.select { |op| op["op"] == "gate" }.each do |op|
          version = find.call(op) or next
          op.slice(*GATE_FIELDS).each { |field, value| version[field] = value }
        end
        ops.select { |op| op["op"] == "description" }.each do |op|
          version = find.call(op) or next
          op.slice(*DESCRIPTION_FIELDS).each { |field, value| version[field] = value }
        end
        by_identity.values
      end
    end
  end
end
