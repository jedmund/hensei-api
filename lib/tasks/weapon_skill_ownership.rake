# frozen_string_literal: true

namespace :granblue do
  desc "Audit ownership boundaries across weapon_skill_data/effects/boost_types JSON. Exits nonzero on errors."
  task audit_weapon_skill_ownership: :environment do
    result = Granblue::WeaponSkillDataOwnershipAuditor.run

    result.findings.each do |finding|
      puts "[#{finding.severity.to_s.upcase}] #{finding.code}: #{finding.message}"
      puts "  #{finding.context.to_json}"
    end

    errors = result.findings.count { |finding| finding.severity == :error }
    warnings = result.findings.count { |finding| finding.severity == :warning }
    abort "Weapon skill ownership audit failed: #{errors} error(s), #{warnings} warning(s)." unless result.ok

    puts "Weapon skill ownership audit passed: #{warnings} warning(s)."
  end
end
