# frozen_string_literal: true

require_relative '../siero/rateup_identity'

namespace :siero do
  desc 'Read-only aggregate rate-up identity preflight/reconciliation (supports legacy schema)'
  task rateup_preflight: :environment do
    report = Siero::RateupIdentity.new.report
    puts report.to_json
    abort 'Rate-up reconciliation requires backfill or explicit repair' unless report.fetch('ready_for_cutover')
  end

  desc 'Rerun validated rate-up identity backfill; preserves conflicts and duplicates'
  task rateup_backfill: :environment do
    report = Siero::RateupIdentity.new.backfill
    puts report.to_json
    abort 'Backfill committed; explicit repair remains before cutover' unless report.fetch('ready_for_cutover')
  end
end
