# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobSearchQuery do
  def call(locale: 'en', **params)
    described_class.call(ActionController::Parameters.new(params).permit!, locale: locale)
  end

  let!(:row_five) do
    create(:job, name_en: 'Zyxfive', name_jp: 'ズィクスい', row: '5', order: 2, proficiency1: 3, proficiency2: 4,
                 master_level: false)
  end
  let!(:row_four) do
    create(:job, name_en: 'Zyxfour', name_jp: 'ズィクスあ', row: '4', order: 1, proficiency1: 5, proficiency2: 6,
                 master_level: true)
  end

  it 'ORs the second proficiency slot onto the other filters' do
    expect(call(filters: { 'row' => ['5'], 'proficiency' => [6] }).to_a & [row_five, row_four]).to eq([row_four])
  end

  it 'applies feature flags to both proficiency slots' do
    expect(call(filters: { 'proficiency' => [3, 6], 'masterLevel' => 'true' }).to_a & [row_five, row_four])
      .to eq([row_four])
  end

  it 'searches the language name' do
    expect(call(query: 'ズィクスい', locale: 'ja').to_a).to eq([row_five])
  end

  it 'lists by row, then order, by default' do
    expect(call.to_a & [row_five, row_four]).to eq([row_four, row_five])
  end

  it 'sorts by the language name' do
    expect(call(sort: 'name').to_a & [row_five, row_four]).to eq([row_five, row_four])
    expect(call(sort: 'name', locale: 'ja').to_a & [row_five, row_four]).to eq([row_four, row_five])
  end
end
