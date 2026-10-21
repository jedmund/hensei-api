# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AddLeciaStyleJpSkillText' do
  let(:migration_class) do
    require Rails.root.join('db/data/20261020220000_add_lecia_style_jp_skill_text') unless defined?(AddLeciaStyleJpSkillText)
    AddLeciaStyleJpSkillText
  end

  def run = migration_class.new.tap { |m| m.verbose = false }.up

  it "stores the six skills on Lecia's style row only, idempotently" do
    base, style = Character.without_skill_build do
      [create(:character, granblue_id: '3040101000', style_swap: false),
       create(:character, granblue_id: '3040101000', style_swap: true)]
    end

    run
    run

    text = Source.read(style, :jp_skill_text)
    expect(text['source']).to eq('official blog, Lecia style shift intro')
    expect(text['skills'].map { |s| [s['kind'], s['position'], s['name_jp']] }).to eq(
      [['ability', 1, 'ソニックバースト'], ['ability', 2, 'ウインドベール'], ['ability', 3, '碧の剣風'],
       ['ougi', 1, 'トワイライトソード・リユニオン'], ['support', 1, '秩序の騎空団総団長'], ['support', 2, '碧の鎧']]
    )
    expect(Source.fetch(style, :jp_skill_text).fetched_at).to be_nil
    expect(Source.fetch(base, :jp_skill_text)).to be_nil
    expect(Source.where(kind: 'jp_skill_text').count).to eq(1)
  end

  it 'does nothing without the style row' do
    expect { run }.not_to change(Source, :count)
  end
end
