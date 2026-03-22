# frozen_string_literal: true

class FixQuirkArtifactProficiencies < ActiveRecord::Migration[7.1]
  def up
    # The old importer passed game `kind` values through directly, but
    # the game uses a different proficiency ordering than our API enum.
    #
    # Game:  1=Sabre, 2=Dagger, 3=Spear, 4=Axe, 5=Staff, 6=Gun, 7=Melee, 8=Bow, 9=Harp, 10=Katana
    # Ours:  1=Sabre, 2=Dagger, 3=Axe,   4=Spear, 5=Bow, 6=Staff, 7=Melee, 8=Harp, 9=Gun, 10=Katana
    #
    # Only quirk artifacts store proficiency on collection_artifacts;
    # standard artifacts inherit it from the artifact record.
    quirk_artifact_ids = Artifact.where(rarity: :quirk).pluck(:id)
    return if quirk_artifact_ids.empty?

    # old_value => correct_value (only values that differ)
    remapping = {
      3 => 4,  # was Axe(3), should be Spear(4)
      4 => 3,  # was Spear(4), should be Axe(3)
      5 => 6,  # was Bow(5), should be Staff(6)
      6 => 9,  # was Staff(6), should be Gun(9)
      8 => 5,  # was Harp(8), should be Bow(5)
      9 => 8   # was Gun(9), should be Harp(8)
    }

    # Use a single CASE statement to swap all values atomically
    execute <<-SQL.squish
      UPDATE collection_artifacts
      SET proficiency = CASE proficiency
        #{remapping.map { |old, new_val| "WHEN #{old} THEN #{new_val}" }.join("\n        ")}
      END
      WHERE artifact_id IN (#{quirk_artifact_ids.join(',')})
        AND proficiency IN (#{remapping.keys.join(',')})
    SQL
  end

  def down
    quirk_artifact_ids = Artifact.where(rarity: :quirk).pluck(:id)
    return if quirk_artifact_ids.empty?

    # Reverse the mapping
    remapping = {
      4 => 3,
      3 => 4,
      6 => 5,
      9 => 6,
      5 => 8,
      8 => 9
    }

    execute <<-SQL.squish
      UPDATE collection_artifacts
      SET proficiency = CASE proficiency
        #{remapping.map { |old, new_val| "WHEN #{old} THEN #{new_val}" }.join("\n        ")}
      END
      WHERE artifact_id IN (#{quirk_artifact_ids.join(',')})
        AND proficiency IN (#{remapping.keys.join(',')})
    SQL
  end
end
