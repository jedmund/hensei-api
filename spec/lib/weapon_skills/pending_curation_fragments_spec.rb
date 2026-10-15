# frozen_string_literal: true

require "rails_helper"

# W2's structural curation (gate and add_version ops) waits in pending fragments until
# the overlay v2 applier folds them in. Each one must already be valid overlay v2.
RSpec.describe "pending weapon-skill curation fragments" do
  fragments = Rails.root.glob("data/weapon_skill_curation/pending/*.json").sort

  it "has fragments to check" do
    expect(fragments).not_to be_empty
  end

  fragments.each do |path|
    it "#{path.basename} is valid overlay v2" do
      expect(WeaponSkills::OverlaySchema.validate(JSON.parse(path.read))).to eq([])
    end
  end
end
