# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::GamePayload do
  let(:jp) { JSON.parse(Rails.root.join('spec/fixtures/character_skills/character-super-cidala-gamedata-jp.json').read) }
  let(:en) { JSON.parse(Rails.root.join('spec/fixtures/character_skills/character-super-cidala-gamedata.json').read) }

  it 'judges the language from the skill names' do
    expect(described_class.language(jp)).to eq('jp')
    expect(described_class.language(en)).to eq('en')
    expect(described_class.language({ 'id' => '1' })).to be_nil
    expect(described_class.language({ 'special_skill' => { 'name' => '奥義' } })).to eq('jp')
  end

  it 'takes the character from master.id and the style from style or param.style' do
    expect(described_class.granblue_id(jp.merge('id' => '194127733'))).to eq('3040377000')
    expect(described_class.granblue_id({ 'id' => '3040377000' })).to eq('3040377000')
    expect(described_class.style(jp)).to eq('2')
    expect(described_class.style({ 'param' => { 'style' => '2' } })).to eq('2')
    expect(described_class.style({})).to eq('')
  end

  it 'reads a malformed body as saying nothing' do
    [nil, [], 'text', { 'master' => 'x', 'param' => [1] }, { 'master' => { 'id' => { 'a' => 1 } } }].each do |body|
      expect([described_class.granblue_id(body), described_class.style(body), described_class.series_id(body)])
        .to eq([nil, '', nil])
    end
    expect(described_class.series_id(jp)).to eq('6')
    expect(described_class.series_id({ 'series_id' => { 'a' => 1 } })).to be_nil
  end
end
