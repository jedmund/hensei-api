# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WikiProfile do
  describe '.normalize' do
    {
      'Eden' => 'Eden',
      '  DY_DK ' => 'DY_DK',
      'User:Fangzsx' => 'Fangzsx',
      'https://gbf.wiki/User:ItsJustSly' => 'ItsJustSly',
      'gbf.wiki/User:Some%20One' => 'Some One',
      'https://gbf.wiki/User:Eden#top' => 'Eden',
      'https://gbf.wiki/index.php?title=User:Eden&action=edit' => 'Eden'
    }.each do |typed, stored|
      it "stores #{typed.inspect} as #{stored.inspect}" do
        expect(described_class.normalize(typed)).to eq(stored)
      end
    end

    it 'turns blanks into nil' do
      expect([nil, '', '  '].map { |v| described_class.normalize(v) }).to all(be_nil)
    end

    it 'leaves what is not a username for the validation to reject' do
      ['https://gbf.wiki/Siero', 'https://gbf.wiki/User:Eden/Teams', 'a|b', 'https://example.com/User:Eden'].each do |typed|
        expect(described_class.normalize(typed)).not_to match(described_class::FORMAT)
      end
    end
  end
end
