# frozen_string_literal: true

# Replays the weapon-specific skill curation from July 2026 that was made directly in
# the dev database and never shipped (Voltage II rates, Destroyer tiers, Tyranny's HP
# cut, Sephirath gating, Cosmic weapon-stat rows, triggered-effect rows the parser no
# longer produces, and the golden-panel curations). The operations live in
# db/data/manifests/july_calculator_recovery.json, keyed by weapon granblue_id and
# skill name; each one records its source and confidence.
#
# Every write is stamped manually_edited_at + provenance "manual" so reparse and the
# family importer leave it alone. Rows already curated by hand are never deleted.
#
# Its lasting state is in the curation overlay (data/weapon_skill_curation/): the rows
# and overrides were exported as curation, and the min_uncap changes are `gate` ops.
# Once the manifest is gone this migration does nothing.
class RecoverJulyWeaponSkillCuration < ActiveRecord::Migration[8.0]
  MANIFEST = "db/data/manifests/july_calculator_recovery.json"
  VERSION_COLUMNS = %w[min_uncap modifier_override series_override size_override].freeze

  def up
    return say("#{MANIFEST} is gone: the July curation is in the curation overlay") unless File.exist?(Rails.root.join(MANIFEST))

    [WeaponSkillEffect, WeaponSkillDatum, WeaponSkillVersion].each(&:reset_column_information)
    @now = Time.current
    operations = JSON.parse(File.read(Rails.root.join(MANIFEST))).fetch("operations")
    # The deploy log is prod's only signal that a skill was renamed or a row already gone.
    unmatched = operations.reject { |operation| matches?(operation) }
    unmatched.each { |op| say "no match: #{op['id']} #{op['op']} #{op['weapon']} / #{op['skill']} #{op['match']&.to_json}" }
    operations.each { |operation| apply(operation) }
    say "#{operations.size} operations, #{unmatched.size} matched nothing"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "restores curation that was lost, not a reversible change"
  end

  private

  def apply(operation)
    case operation.fetch("op")
    when "insert_effect" then versions(operation).each { |v| insert_effect(operation["attrs"], v.id) }
    when "delete_effect" then delete_effects(operation)
    when "update_effect" then update_effects(operation)
    when "update_version" then versions(operation).each { |v| update_version(v, operation["set"]) }
    when "insert_datum" then versions(operation).each { |v| insert_datum(operation["attrs"], v.id) }
    when "insert_key_effect" then insert_effect(operation["attrs"], nil)
    else raise "unknown recovery op #{operation['op']}"
    end
  end

  def matches?(operation)
    case operation["op"]
    when "insert_key_effect" then true
    when "delete_effect", "update_effect"
      effect_scope(operation).exists? || (operation["insert_if_missing"] && versions(operation).exists?)
    else versions(operation).exists?
    end
  end

  def versions(operation)
    WeaponSkillVersion.joins(:skill, :weapon_skill)
                      .where(weapon_skills: { weapon_granblue_id: operation.fetch("granblue_id") },
                             skills: { name_en: operation.fetch("skill") })
  end

  def stamp
    { manually_edited_at: @now, provenance: "manual" }
  end

  def insert_effect(attrs, version_id)
    identity = { weapon_skill_version_id: version_id, modifier: attrs["modifier"],
                 boost_type: attrs["boost_type"], key_slug: attrs["key_slug"],
                 condition: attrs["condition"] || {} }
    return if WeaponSkillEffect.exists?(identity)

    WeaponSkillEffect.create!(attrs.merge(identity.stringify_keys).merge(stamp))
  end

  def effect_scope(operation)
    match = operation.fetch("match")
    scope = WeaponSkillEffect.where(weapon_skill_version_id: versions(operation).select(:id),
                                    boost_type: match.fetch("boost_type"))
    match.key?("value") ? scope.where(value: match["value"]) : scope
  end

  def delete_effects(operation)
    effect_scope(operation).where(manually_edited_at: nil).delete_all
  end

  def update_effects(operation)
    scope = effect_scope(operation)
    if scope.exists?
      scope.find_each { |effect| effect.update!(operation.fetch("set").merge(stamp)) }
    elsif operation["insert_if_missing"]
      versions(operation).each { |v| insert_effect(operation["insert_if_missing"], v.id) }
    end
  end

  def update_version(version, set)
    attrs = set.slice(*VERSION_COLUMNS)
    attrs["suppressed_boosts"] = (Array(version.suppressed_boosts) | set["suppressed_boosts"]) if set["suppressed_boosts"]
    attrs["overrides_edited_at"] = @now if attrs.except("min_uncap").any?
    version.update!(attrs)
  end

  def insert_datum(attrs, version_id)
    identity = { weapon_skill_version_id: version_id, modifier: attrs["modifier"], boost_type: attrs["boost_type"] }
    return if WeaponSkillDatum.exists?(identity)

    WeaponSkillDatum.create!(attrs.merge(identity.stringify_keys).merge(stamp))
  end
end
