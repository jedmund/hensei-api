# frozen_string_literal: true

namespace :granblue do
  desc "Audit ownership boundaries across weapon_skill_data/effects/boost_types JSON. Exits nonzero on errors."
  task audit_weapon_skill_ownership: :environment do
    result = Granblue::WeaponSkillDataOwnershipAuditor.run

    result.findings.each do |finding|
      puts "[#{finding.severity.to_s.upcase}] #{finding.code}: #{finding.message}"
      puts "  #{finding.context.to_json}"
    end

    db_null_errors = WeaponSkillEffect.base_effects.where(value: nil).reject do |effect|
      scaling_kind = effect.scaling_kind
      key = [effect.modifier, effect.boost_type, scaling_kind, effect.key_slug]
      Granblue::WeaponSkillDataOwnershipAuditor::TABLE_VALUED_SCALING_KINDS.include?(scaling_kind) ||
        Granblue::WeaponSkillDataOwnershipAuditor::DOCUMENTATION_SCALING_KINDS.include?(scaling_kind) ||
        Granblue::WeaponSkillDataOwnershipAuditor::INTENTIONAL_NULL_EFFECTS.key?(key)
    end

    db_null_errors.each do |effect|
      puts "[ERROR] unclassified_db_null_effect: Canonical DB effect has nil value without an allowed null classification."
      puts "  #{{
        modifier: effect.modifier,
        boost_type: effect.boost_type,
        scaling_kind: effect.scaling_kind,
        key_slug: effect.key_slug
      }.compact.to_json}"
    end

    errors = result.findings.count { |finding| finding.severity == :error } + db_null_errors.size
    warnings = result.findings.count { |finding| finding.severity == :warning }
    unless result.ok && db_null_errors.empty?
      abort "Weapon skill ownership audit failed: #{errors} error(s), #{warnings} warning(s)."
    end

    puts "Weapon skill ownership audit passed: #{warnings} warning(s)."
  end
end
