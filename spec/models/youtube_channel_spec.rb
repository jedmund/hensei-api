# frozen_string_literal: true

require 'rails_helper'

RSpec.describe YoutubeChannel do
  describe '.normalize' do
    {
      'matcha_soba' => '@matcha_soba',
      '@matcha_soba' => '@matcha_soba',
      '  dy_dk ' => '@dy_dk',
      'https://www.youtube.com/@SlyIIBoT' => '@SlyIIBoT',
      'youtube.com/@astraldelight/videos' => '@astraldelight',
      'https://m.youtube.com/@some.one?si=abc' => '@some.one',
      'https://www.youtube.com/channel/UCjH35rEofoTkw81IrDukb5w' => 'channel/UCjH35rEofoTkw81IrDukb5w',
      # Already stored: saving again leaves it alone
      'channel/UCjH35rEofoTkw81IrDukb5w' => 'channel/UCjH35rEofoTkw81IrDukb5w'
    }.each do |typed, stored|
      it "stores #{typed.inspect} as #{stored.inspect}" do
        expect(described_class.normalize(typed)).to eq(stored)
      end
    end

    it 'turns blanks into nil' do
      expect([nil, '', '   '].map { |v| described_class.normalize(v) }).to all(be_nil)
    end

    it 'leaves what it cannot read for the validation to reject' do
      ['https://youtube.com/watch?v=abc', 'https://example.com/@x', 'two words'].each do |typed|
        expect(described_class.normalize(typed)).not_to match(described_class::FORMAT)
      end
    end
  end
end
