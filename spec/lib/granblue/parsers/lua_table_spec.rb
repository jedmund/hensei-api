# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Parsers::LuaTable do
  let(:data) { described_class.parse(File.read(Rails.root.join('spec/fixtures/wiki/status_list_extract.lua'))) }

  it 'reads local tables and resolves the names the return table uses' do
    expect(data.keys).to contain_exactly('aliases', 'buffs', 'debuffs', 'effects')
    expect(data['aliases']).to eq('DEF Down 4' => 'DEF Lowered 4', '5% Cut' => '5% DMG Cut')
  end

  it 'reads nested tables, escapes, long strings, and skips comments' do
    expect(data['buffs']['5% DMG Cut']).to eq('link' => 'DMG Cut', 'name' => '5% DMG Cut', 'detail' => 'Taking 5% less DMG',
                                              'status' => '1019_0_5')
    expect(data['buffs']['Wild Card']['detail']).to eq('It\'s a "wild" card')
    expect(data['buffs']['Wild Card']['wiki_comment']).to eq("<table>\n<tr><td>long</td></tr></table>")
    expect(data['buffs']['DMG Cut']['groups']).to eq({})
    expect(data['debuffs']).to have_key('Accuracy Lowered 2')
  end

  it 'reads arrays, numbers and booleans' do
    expect(described_class.parse("local t = { 'a', 2, 3.5, true, nil }\nreturn { t = t, f = false }"))
      .to eq('t' => ['a', 2, 3.5, true, nil], 'f' => false)
  end

  it 'keeps the positional values of a mixed table under 1, 2, …' do
    expect(described_class.parse("return { 'a', name = 'b', 'c' }")).to eq('name' => 'b', 1 => 'a', 2 => 'c')
  end

  it 'reports where the source stops making sense' do
    expect { described_class.parse("local t = { ['a'] = }\nreturn t") }.to raise_error(described_class::SyntaxError, /line 1/)
  end
end
