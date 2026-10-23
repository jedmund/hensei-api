# frozen_string_literal: true

namespace :granblue do
  desc "Validate the calculator against checked-in in-game panels (data/panel_references/*.json). " \
       "party=<shortcode> for one; default all. Exits nonzero on mismatch."
  task validate_panel: :environment do
    results = Granblue::PanelValidator.run(party: ENV.fetch("party", nil))
    abort "no panel references found" if results.empty?

    results.each do |r|
      puts "== #{r.party} (captured #{r.captured_on}) =="
      r.mismatches.each do |m|
        printf("  %-22<label>s %12<ours>s  panel %-10<expected>s MISMATCH\n",
               label: m[:label], ours: m[:ours] || "—", expected: m[:expected])
      end
      puts "  all lines match" if r.ok
    end

    failed = results.count { |r| !r.ok }
    abort "#{failed} panel reference(s) FAILED" if failed.positive?
    puts "All #{results.size} panel reference(s) match."
  end
end
