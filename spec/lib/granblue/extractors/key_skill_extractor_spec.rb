# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("lib/granblue/extractors/key_skill_extractor")

RSpec.describe Granblue::Extractors::KeySkillExtractor do
  describe ".persist" do
    it "does not replace curated Dark Opus key effects" do
      stats = Hash.new(0)

      expect(WeaponSkillEffect).not_to receive(:for_key)
      expect(WeaponSkillEffect).not_to receive(:create!)

      described_class.send(:persist, "chain-forbiddance", [{ value: 10 }], stats)

      expect(stats[:curated_skipped]).to eq(1)
    end
  end
end
