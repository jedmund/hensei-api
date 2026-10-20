# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EventTopImage do
  it 'finds the first image before the first heading' do
    wikitext = "{{PageGroupCrew}}\n[[File:Dread_Barrage_top.jpg|link=]]\n\n'''Dread Barrage''' is an event.\n" \
               "==Battles==\n[[File:Icon_Gold_Chest.png]]"
    expect(described_class.file_name(wikitext)).to eq('Dread_Barrage_top.jpg')
  end

  it 'reads file names with spaces, commas and captions' do
    expect(described_class.file_name("{{EventHelper|name=x}}\n[[File:Farewell, Cold Heart top.jpg|link=]]"))
      .to eq('Farewell, Cold Heart top.jpg')
    expect(described_class.file_name('[[File:riseofthebeasts_top.png|link=|Rise of the Beasts Banner]]'))
      .to eq('riseofthebeasts_top.png')
  end

  it 'returns nil when the intro has no image' do
    expect(described_class.file_name("Intro text.\n==Section==\n[[File:later.png]]")).to be_nil
    expect(described_class.file_name(nil)).to be_nil
  end
end
