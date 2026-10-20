# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::JpWikiPage do
  let(:page) do
    <<~HTML
      <!DOCTYPE html><html><head><title>ヴィーラ</title><script>var x = 1;</script></head>
      <body><div id="menubar">メニュー</div>
      <div id="body"><h2>アビリティ</h2><table class="style_table"><tr><td>名称</td><td>効果</td></tr></table></div>
      <div id="footer">フッター</div></body></html>
    HTML
  end

  it 'keeps div#body and drops the rest of the page' do
    trimmed = described_class.trim(page)

    expect(trimmed).to start_with('<div id="body">')
    expect(trimmed).to include('<h2>アビリティ</h2>', 'table class="style_table"')
    expect(trimmed).not_to include('メニュー', 'フッター', '<title>', 'var x')
  end

  it 'keeps Japanese text literal' do
    expect(described_class.trim(page)).not_to match(/&#\d+;/)
  end

  it 'is idempotent, so a refetch of an unchanged page compares equal' do
    trimmed = described_class.trim(page)
    expect(described_class.trim(trimmed)).to eq(trimmed)
  end

  it 'returns a page without div#body, and blank input, as given' do
    expect(described_class.trim('<html><body>Not found</body></html>')).to eq('<html><body>Not found</body></html>')
    expect(described_class.trim(nil)).to be_nil
    expect(described_class.trim('')).to eq('')
  end

  it 'gives the skill parser the same result as the whole page' do
    whole = Granblue::Parsers::JpWikiSkillParser.new(Struct.new(:wiki_raw_jp).new(page)).parse
    trimmed = Granblue::Parsers::JpWikiSkillParser.new(Struct.new(:wiki_raw_jp).new(described_class.trim(page))).parse
    expect(trimmed).to eq(whole)
  end
end
