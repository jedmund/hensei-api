# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::StatusBlueprint do
  it 'shows the name without its wiki level number, with the qualifier that tells it apart (D59)' do
    status = build(:status, wiki_name: 'Asleep 1', name_en: 'Asleep', qualifier: 'Turns')
    expect(JSON.parse(described_class.render(status))).to include('name' => { 'en' => 'Asleep', 'ja' => nil }, 'qualifier' => 'Turns')
  end
end
