# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Parsers::CharacterSkillParser, '.build_status_lookup' do
  it 'indexes statuses by normalized name and by id' do
    veil = create(:status, name_en: 'Veil')
    lookup = described_class.build_status_lookup
    expect(lookup[:by_name]).to eq('veil' => veil)
    expect(lookup[:by_id]).to eq(veil.id => veil)
  end

  it 'finds a status whatever the case or spacing of the name' do
    create(:status, name_en: 'Sun-Touched Paradise')
    expect(described_class.build_status_lookup[:by_name][Status.normalize_name(' sun-touched  paradise')].name_en)
      .to eq('Sun-Touched Paradise')
  end

  it 'refuses a second status with the same name' do
    create(:status, name_en: 'DEF Up')
    expect { create(:status, name_en: 'def up ') }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
