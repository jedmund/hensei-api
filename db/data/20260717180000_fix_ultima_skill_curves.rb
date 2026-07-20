# frozen_string_literal: true

# Replaces the SL20-only Ultima base/standard-key rows with the checked-in
# Rubell and Gauph tables. Standard Gauph effects inherit the base skill's
# weapon-specialty gate; Strength and Zeal reuse the ordinary HP curves.
class FixUltimaSkillCurves < ActiveRecord::Migration[8.0]
  KEY_SLUGS = %w[
    gauph-courage gauph-strength gauph-strife gauph-vitality gauph-will gauph-zeal
  ].freeze
  EXPECTED_ROWS = 9

  LEGACY_MANUAL_ROWS = [
    {
      "key_slug" => "gauph-courage", "modifier" => "Gauph Key of Courage",
      "boost_type" => "critical", "scaling_kind" => "static", "value" => 20.0,
      "value_unit" => "percent"
    },
    {
      "key_slug" => "gauph-strength", "modifier" => "Gauph Key of Strength",
      "boost_type" => "stamina", "series" => "ex", "scaling_kind" => "conditional_flat",
      "value" => 20.4, "value_unit" => "percent",
      "condition" => { "type" => "weapon_specialty" }, "applies_to" => "all_allies"
    },
    {
      "modifier" => "Rubell", "boost_type" => "atk", "series" => "ex",
      "scaling_kind" => "conditional_flat", "value" => 25.0, "value_unit" => "percent",
      "condition" => { "type" => "weapon_specialty" }
    },
    {
      "modifier" => "Rubell", "boost_type" => "hp", "series" => "ex",
      "scaling_kind" => "conditional_flat", "value" => 20.0, "value_unit" => "percent",
      "condition" => { "type" => "weapon_specialty" }
    }
  ].freeze

  SNAPSHOT_COLUMNS = %w[
    modifier boost_type series scaling_kind value value_unit per_copy_cap total_cap
    shared_cap_group cap_formula count_basis count_cap condition target_instance depends_on
    aura_boostable seraphic_affected stacking applies_to battle_interaction notes key_slug frame_rule
  ].freeze
  SIGNATURE_COLUMNS = (SNAPSHOT_COLUMNS - %w[modifier boost_type notes key_slug]).freeze
  SIGNATURE_DEFAULTS = SIGNATURE_COLUMNS.index_with { nil }.merge(
    "condition" => {}, "depends_on" => [], "aura_boostable" => false,
    "seraphic_affected" => false, "stacking" => "additive",
    "applies_to" => "element_allies", "battle_interaction" => false
  ).freeze
  NUMERIC_SIGNATURE_COLUMNS = %w[value per_copy_cap total_cap].freeze

  def up
    WeaponSkillEffect.reset_column_information
    rows = snapshot_rows.select do |row|
      KEY_SLUGS.include?(row["key_slug"]) || (row["key_slug"].nil? && row["modifier"] == "Rubell")
    end
    raise "Expected #{EXPECTED_ROWS} Ultima effect rows, found #{rows.size}" unless rows.size == EXPECTED_ROWS

    scope = target_scope
    assert_manual_rows_are_replaceable!(scope, rows)
    metadata = curation_metadata(scope)
    scope.delete_all

    rows.each do |row|
      attrs = row.slice(*SNAPSHOT_COLUMNS)
      marker = metadata[[row["key_slug"], row["modifier"], row["boost_type"]]]&.shift || {}
      WeaponSkillEffect.create!(attrs.merge(marker))
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "the replaced Ultima effects were lossy SL20 constants"
  end

  private

  def target_scope
    WeaponSkillEffect.where(key_slug: KEY_SLUGS).or(
      WeaponSkillEffect.where(key_slug: nil, weapon_skill_version_id: nil, modifier: "Rubell")
    )
  end

  def assert_manual_rows_are_replaceable!(scope, rows)
    candidates = (LEGACY_MANUAL_ROWS + rows).group_by { |row| identity(row) }
    unexpected = scope.where.not(manually_edited_at: nil).reject do |effect|
      candidates.fetch(identity(effect.attributes), []).any? do |row|
        semantic_signature(effect.attributes) == semantic_signature(row)
      end
    end
    return if unexpected.empty?

    raise "Manual Ultima effects require review before migration: #{unexpected.map(&:id).join(', ')}"
  end

  def curation_metadata(scope)
    scope.group_by { |effect| [effect.key_slug, effect.modifier, effect.boost_type] }
         .transform_values do |effects|
      effects.filter_map do |effect|
        next if effect.manually_edited_at.nil? && effect.provenance.nil?

        { manually_edited_at: effect.manually_edited_at, provenance: effect.provenance }
      end
    end
  end

  def identity(row)
    [row["key_slug"], row["modifier"], row["boost_type"]]
  end

  def semantic_signature(row)
    signature = SIGNATURE_DEFAULTS.merge(row.slice(*SIGNATURE_COLUMNS))
    NUMERIC_SIGNATURE_COLUMNS.each do |column|
      signature[column] = BigDecimal(signature[column].to_s).to_s("F") if signature[column]
    end
    signature
  end

  def snapshot_rows
    payload = JSON.parse(File.read(Rails.root.join("data", "weapon_skill_effects.json")))
    payload.is_a?(Hash) ? payload.fetch("effects") : payload
  end
end
