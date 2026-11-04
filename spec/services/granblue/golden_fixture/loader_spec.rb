# frozen_string_literal: true

require 'rails_helper'

# Fixtures exported before K1 carry character_skills without character_id.
RSpec.describe Granblue::GoldenFixture::Loader do
  def fixture(tables)
    { 'format' => Granblue::GoldenFixture::FORMAT, 'shortcode' => 'TEST01', 'tables' => tables }
  end

  def skill(granblue_id)
    { 'id' => SecureRandom.uuid, 'character_granblue_id' => granblue_id, 'kind' => 'support', 'position' => 1 }
  end

  def owners(loader)
    loader.instance_variable_get(:@tables)['character_skills'].pluck('character_id')
  end

  it "fills a missing owner from the fixture's base character row" do
    base_id = SecureRandom.uuid
    loader = described_class.new(fixture(
                                   'characters' => [
                                     { 'id' => base_id, 'granblue_id' => '3040377000', 'style_swap' => false },
                                     { 'id' => SecureRandom.uuid, 'granblue_id' => '3040377000', 'style_swap' => true }
                                   ],
                                   'character_skills' => [skill('3040377000')]
                                 ), :replace)

    expect(owners(loader)).to eq([base_id])
  end

  it 'falls back to the base row in the database' do
    base = create(:character, granblue_id: '3990000377')
    create(:character, granblue_id: '3990000377', style_swap: true)

    loader = described_class.new(fixture('character_skills' => [skill('3990000377')]), :replace)

    expect(owners(loader)).to eq([base.id])
  end

  it 'names the granblue_id when no base row can be found' do
    expect { described_class.new(fixture('character_skills' => [skill('3999999999')]), :replace) }
      .to raise_error(Granblue::GoldenFixture::Error, /TEST01: no base character row .* of 3999999999/)
  end
end
