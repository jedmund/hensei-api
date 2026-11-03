# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/data/20261103030000_fix_class_ii_job_ids')

RSpec.describe FixClassIiJobIds do
  subject(:migration) { described_class.new }

  before { allow(migration).to receive(:say) }

  # The test schema already has the unique index, so the Class I twin a
  # Class II job shared its id with can't be built here; the Class II row is
  # what moves. Ids are on an unused 90 line, clear of the seeded jobs.
  it 'moves Class II jobs to their tier id, rerunnably' do
    warrior = create(:job, name_en: 'Warrior', granblue_id: '900001', row: '2')
    knight = create(:job, name_en: 'Knight', granblue_id: '910001', row: '1')
    weapon_master = create(:job, name_en: 'Weapon Master', granblue_id: '900201', row: '3')

    2.times { migration.up }

    expect(warrior.reload.granblue_id).to eq('900101')
    expect(knight.reload.granblue_id).to eq('910001')
    expect(weapon_master.reload.granblue_id).to eq('900201')
  end

  it 'leaves a job alone when its new id is taken' do
    warrior = create(:job, name_en: 'Warrior', granblue_id: '900001', row: '2')
    create(:job, name_en: 'Other', granblue_id: '900101', row: '3')

    migration.up

    expect(warrior.reload.granblue_id).to eq('900001')
  end
end
