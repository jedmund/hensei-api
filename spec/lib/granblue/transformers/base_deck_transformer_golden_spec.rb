# frozen_string_literal: true

require 'rails_helper'

# Pins what the deck transformers make of real game decks.
#
# Regenerate with WRITE_GOLDENS=1 only for an intended change, and review the diff.
RSpec.describe Granblue::Transformers::BaseDeckTransformer do
  let(:golden_dir) { Rails.root.join('spec/fixtures/deck_import') }

  def expect_golden(name, actual)
    path = golden_dir.join("#{name}.json")
    if ENV['WRITE_GOLDENS']
      FileUtils.mkdir_p(golden_dir)
      File.write(path, "#{JSON.pretty_generate(actual)}\n")
    end
    expect(actual).to eq(JSON.parse(path.read))
  end

  def deck(fixture)
    JSON.parse(Rails.root.join("spec/fixtures/#{fixture}.json").read)
  end

  # WeaponTransformer reads augment_skill_info as a hash of skills, but the game
  # sends an array, so the goldens take the AX data out.
  def without_ax(data)
    data['deck']['pc']['weapons'].each_value { |weapon| weapon&.dig('param')&.delete('augment_skill_info') }
    data
  end

  it 'raises on the AX data of a real deck' do
    expect { described_class.new({ 'import' => deck('deck_sample2') }).transform }
      .to raise_error(NoMethodError, /each_value/)
  end

  %w[deck_sample deck_sample2].each do |fixture|
    it "transforms #{fixture}.json" do
      result = described_class.new({ 'import' => without_ax(deck(fixture)) }, language: 'ja').transform
      expect_golden("#{fixture}_transformed", JSON.parse(result.to_json))
    end
  end
end
