# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("lib/granblue/extractors/key_skill_extractor")

RSpec.describe Granblue::Extractors::KeySkillExtractor do
  describe ".persist" do
    it "does not replace effects for curated key families" do
      stats = Hash.new(0)

      expect(WeaponSkillEffect).not_to receive(:for_key)
      expect(WeaponSkillEffect).not_to receive(:create!)

      %w[chain-forbiddance pendulum-strength gauph-strength teluma-inferno].each do |slug|
        described_class.send(:persist, slug, [{ value: 10 }], stats)
      end

      expect(stats[:curated_skipped]).to eq(4)
    end
  end
end
