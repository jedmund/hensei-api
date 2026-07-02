# frozen_string_literal: true

namespace :granblue do
  desc "Validate the calculator against checked-in in-game panels (data/panel_references/*.json). " \
       "party=<shortcode> for one; default all. Exits nonzero on mismatch."
  task validate_panel: :environment do
    refs = Rails.root.glob("data/panel_references/*.json")
    refs.select! { |f| f.basename(".json").to_s == ENV["party"] } if ENV["party"]
    abort "no panel references found" if refs.empty?

    failed = refs.reject { |f| validate_panel_reference(JSON.parse(File.read(f))) }
    abort "#{failed.size} panel reference(s) FAILED" if failed.any?
    puts "All #{refs.size} panel reference(s) match."
  end

  # The panel floors displayed integers (HP 249.8 shows 249), so an integer reference
  # matches when our floored value equals it; decimal references must match to 0.005.
  def panel_value_matches?(ours, ref)
    return false if ours.nil?

    (ours - ref).abs <= 0.005 || (ref == ref.floor && ours.floor == ref)
  end

  def validate_panel_reference(ref)
    party = Party.find_by!(shortcode: ref.fetch("party"))
    state = ref.fetch("state", {}).symbolize_keys
    agg = GridDamage::Calculator.boost_list(party, state: state)
    enh = GridDamage::Calculator.send(:enhancements, party, agg)

    puts "== #{ref['party']} (captured #{ref['captured_on']}) =="
    ok = true
    ref.fetch("enhancements", {}).each do |frame, expected|
      ok &= report("#{frame.capitalize} Enh", enh[frame.to_sym], expected)
    end
    ref.fetch("lines").each do |line|
      result = agg[line.fetch("boost")]
      ours = if line["series"]
               result&.by_series&.dig(line["series"])&.to_f # rubocop:disable Style/SafeNavigationChainLength
             else
               result&.total&.to_f
             end
      ok &= report(line.fetch("label"), ours, line.fetch("value").to_f)
    end
    ok
  end

  def report(label, ours, expected)
    match = panel_value_matches?(ours, expected)
    printf("  %-22<label>s %12<ours>s  panel %-10<expected>s %<verdict>s\n",
           label: label, ours: ours.nil? ? "—" : ours.round(2), expected: expected,
           verdict: match ? "ok" : "MISMATCH")
    match
  end
end
