# frozen_string_literal: true

# Completes the finite Draconic Teluma inventory from the checked-in series
# table. The migration also repairs clean-database key/series coverage for the
# two Provenance-only Telumas and adds Light/Dark reduction panel metadata.
class CompleteDraconicTelumaEffects < ActiveRecord::Migration[8.0]
  PROVENANCE_ONLY = %w[teluma-salvation teluma-oblivion].freeze
  EXPECTED_EFFECT_ROWS = 13

  LEGACY_MANUAL_ROWS = [
    {
      "key_slug" => "teluma-oblivion", "modifier" => "Oblivion Teluma",
      "boost_type" => "plain_amp", "series" => "ex", "scaling_kind" => "static",
      "value" => 10.0, "value_unit" => "percent"
    }
  ].freeze

  KEYS = {
    "teluma-endurance" => [
      "ee80ff09-71c0-48bb-90ff-45e138df7481", "Endurance Teluma", "剛堅のテルマ", 15001, 0, 0
    ],
    "teluma-inferno" => [
      "dc96edb7-8bee-4721-94c2-daa6508aaed8", "Inferno Teluma", "炎獄のテルマ", 15002, 0, 1
    ],
    "teluma-abyss" => [
      "d14e933e-630d-4cd6-9d61-dbdfd6e9332e", "Abyss Teluma", "深海のテルマ", 15003, 0, 2
    ],
    "teluma-crag" => [
      "1929bfa8-6bbd-4918-9ad7-594525b5e2c6", "Crag Teluma", "巨岩のテルマ", 15004, 0, 3
    ],
    "teluma-tempest" => [
      "49f46e22-1796-435e-bce2-d9fdfe76d6c5", "Tempest Teluma", "暴風のテルマ", 15005, 0, 4
    ],
    "teluma-aureole" => [
      "e36950be-1ea9-4642-af94-164187e38e6c", "Aureole Teluma", "後光のテルマ", 15006, 0, 5
    ],
    "teluma-malice" => [
      "81950efb-a4e1-4d45-8572-ddb604246212", "Malice Teluma", "闇禍のテルマ", 15007, 0, 6
    ],
    "teluma-salvation" => [
      "d79558df-53fb-4c24-963b-e0b67040afc7", "Salvation Teluma", "燦護のテルマ", 15008, 0, 7
    ],
    "teluma-oblivion" => [
      "b0b6d3be-7203-437e-8acd-2a59c2b5506a", "Oblivion Teluma", "冥烈のテルマ", 15009, 0, 8
    ],
    "teluma-optimus" => [
      "0c6ce91c-864c-4c62-8c9b-be61e8fae47f", "Optimus Teluma", "オプティマス・テルマ", 16001, 1, 0
    ],
    "teluma-omega" => [
      "3fa65774-1ed1-4a16-86cd-9133adca2232", "Omega Teluma", "マグナ・テルマ", 16002, 1, 1
    ]
  }.freeze

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
    rows = snapshot_rows.select { |row| KEYS.key?(row["key_slug"]) }
    unless rows.size == EXPECTED_EFFECT_ROWS
      raise "Expected #{EXPECTED_EFFECT_ROWS} Teluma effect rows, found #{rows.size}"
    end

    scope = WeaponSkillEffect.where(key_slug: KEYS.keys)
    assert_manual_rows_are_replaceable!(scope, rows)

    ensure_keys
    upsert_panel_metadata

    metadata = curation_metadata(scope)
    scope.delete_all
    rows.each do |row|
      attrs = row.slice(*SNAPSHOT_COLUMNS)
      marker = metadata[[row["key_slug"], row["modifier"], row["boost_type"]]]&.shift || {}
      WeaponSkillEffect.create!(attrs.merge(marker))
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "the replaced Teluma data was incomplete and partly mislabeled"
  end

  private

  def ensure_keys
    series_by_slug = WeaponSeries.where(slug: %w[draconic draconic-providence]).index_by(&:slug)
    missing_series = %w[draconic draconic-providence] - series_by_slug.keys
    raise "Missing weapon series: #{missing_series.join(', ')}" if missing_series.any?

    KEYS.each do |slug, (id, name_en, name_jp, granblue_id, slot, order)|
      key = WeaponKey.find_by(slug: slug) || WeaponKey.find_by(granblue_id: granblue_id) ||
            WeaponKey.new(id: id)
      legacy_series = PROVENANCE_ONLY.include?(slug) ? [40] : [27, 40]
      key.update!(slug: slug, name_en: name_en, name_jp: name_jp, granblue_id: granblue_id,
                  slot: slot, group: 2, order: order, series: legacy_series)

      compatible_slugs = if PROVENANCE_ONLY.include?(slug)
                           %w[draconic-providence]
                         else
                           %w[draconic draconic-providence]
                         end
      compatible_series = compatible_slugs.map { |series_slug| series_by_slug.fetch(series_slug) }
      key.weapon_key_series.where.not(weapon_series_id: compatible_series.map(&:id)).delete_all
      compatible_slugs.each do |series_slug|
        WeaponKeySeries.find_or_create_by!(
          weapon_key: key, weapon_series: series_by_slug.fetch(series_slug)
        )
      end
    end
  end

  def upsert_panel_metadata
    %w[light dark].each do |element|
      WeaponSkillBoostType.find_or_initialize_by(key: "#{element}_reduc").update!(
        name_en: "#{element.capitalize} Reduc.", category: "defensive", grid_cap: nil,
        display_cap: 30, cap_is_flat: false, stacking_rule: "additive", amplifiable: false,
        notes: "Reduce #{element} damage taken."
      )
    end

    GridDamage::PanelPresenter::LINES.each_with_index do |(key, series, label, slug, group), position|
      PanelLine.find_or_initialize_by(boost_type: key, series: series).update!(
        label_en: label, slug: slug, group_name: group, position: position
      )
    end
  end

  def assert_manual_rows_are_replaceable!(scope, rows)
    candidates = (LEGACY_MANUAL_ROWS + rows).group_by { |row| identity(row) }
    unexpected = scope.where.not(manually_edited_at: nil).reject do |effect|
      candidates.fetch(identity(effect.attributes), []).any? do |row|
        semantic_signature(effect.attributes) == semantic_signature(row)
      end
    end
    return if unexpected.empty?

    raise "Manual Draconic effects require review before migration: #{unexpected.map(&:id).join(', ')}"
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
