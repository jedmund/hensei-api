# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::JpWikiTitle do
  # Stored wiki_ja values from the catalogue.
  let(:utf8) do
    '%E3%82%B8%E3%83%BC%E3%82%AF%E3%83%95%E3%83%AA%E3%83%BC%E3%83%88+%28SSR%29' \
      '%E3%82%A2%E3%83%8A%E3%82%B6%E3%83%BC%E3%83%90%E3%83%BC%E3%82%B8%E3%83%A7%E3%83%B3'
  end
  let(:euc_jp) { '%A5%D7%A5%EA%A5%AD%A5%E5%A5%A2%20%28SSR%29' }
  let(:truncated) { '%A5%B7%A5%E3%A5%EB%A5%ED%A5%C3%A5%C6%20%28SSR%29%A5%EA%A5%DF%A5%C6%A5%C3%A5%C9%A5%' }

  describe '.decode_with_encoding' do
    it 'decodes UTF-8 with + for spaces' do
      expect(described_class.decode_with_encoding(utf8)).to eq(['ジークフリート (SSR)アナザーバージョン', :utf8])
    end

    it 'decodes legacy EUC-JP' do
      expect(described_class.decode_with_encoding(euc_jp)).to eq(['プリキュア (SSR)', :euc_jp])
    end

    it 'decodes a title that is only partly encoded' do
      expect(described_class.decode_with_encoding('召喚石/東堂+葵+%28SSR%29')).to eq(['召喚石/東堂 葵 (SSR)', :utf8])
    end

    it 'reads EUC-JP bytes that are also valid UTF-8 as EUC-JP when only that is Japanese' do
      # 猫 is C7 AD in EUC-JP, which is ǭ in UTF-8.
      expect(described_class.decode_with_encoding('%C7%AD%20%28R%29')).to eq(['猫 (R)', :euc_jp])
    end

    it 'passes a plain title through, trimmed' do
      expect(described_class.decode_with_encoding(' フロレンス (SSR) ')).to eq(['フロレンス (SSR)', :plain])
    end

    it 'gives nil for a title cut off mid-escape or in neither encoding' do
      expect(described_class.decode_with_encoding(truncated)).to be_nil
      expect(described_class.decode_with_encoding('C9%F0%B4%EF%2F%CD%BF')).to be_nil
      expect(described_class.decode_with_encoding(nil)).to be_nil
    end
  end

  describe '.decode!' do
    it 'raises a clear error for an undecodable title' do
      expect { described_class.decode!(truncated) }
        .to raise_error(described_class::InvalidTitle, /stored Japanese wiki title/)
    end

    it 'returns the plain title otherwise' do
      expect(described_class.decode!(euc_jp)).to eq('プリキュア (SSR)')
      expect(described_class.decode!('')).to eq('')
    end
  end

  describe 'wiki_ja on the item models' do
    it 'stores a pasted percent-encoded title plain' do
      expect(build(:character, wiki_ja: utf8).wiki_ja).to eq('ジークフリート (SSR)アナザーバージョン')
      expect(build(:weapon, wiki_ja: euc_jp).wiki_ja).to eq('プリキュア (SSR)')
      expect(build(:summon, wiki_ja: ' 召喚石/アグニス (SSR)').wiki_ja).to eq('召喚石/アグニス (SSR)')
    end

    it 'keeps an undecodable title as given for an editor to fix' do
      expect(build(:character, wiki_ja: truncated).wiki_ja).to eq(truncated)
    end
  end
end
