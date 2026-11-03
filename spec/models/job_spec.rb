# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Job, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:skills).class_name('JobSkill') }
    it { is_expected.to belong_to(:base_job).class_name('Job').optional }
  end

  describe 'display_resource' do
    it 'returns name_en' do
      job = create(:job, name_en: 'Dark Fencer')
      expect(job.display_resource(job)).to eq('Dark Fencer')
    end
  end

  describe 'search' do
    it 'can search by English name' do
      job = create(:job, name_en: 'Berserker')
      results = Job.en_search('Berserker')
      expect(results).to include(job)
    end
  end

  describe 'validations' do
    it 'requires a unique 6-digit granblue_id' do
      expect(build(:job, granblue_id: nil)).not_to be_valid
      expect(build(:job, granblue_id: '1000010')).not_to be_valid

      first = create(:job, granblue_id: '900001', row: '1')
      expect(build(:job, granblue_id: first.granblue_id, row: '1')).not_to be_valid
      expect(build(:job, granblue_id: first.granblue_id, row: '2')).not_to be_valid
    end

    it 'requires both names' do
      expect(build(:job, name_en: ' ')).not_to be_valid
      expect(build(:job, name_jp: nil)).not_to be_valid
    end

    it 'accepts only known rows, proficiencies and accessory types' do
      expect(build(:job, row: 'ex')).not_to be_valid
      expect(build(:job, row: 'ex1')).to be_valid
      expect(build(:job, proficiency1: 0)).not_to be_valid
      expect(build(:job, proficiency2: 11)).not_to be_valid
      expect(build(:job, accessory_type: 3)).not_to be_valid
      expect(build(:job, order: -1)).not_to be_valid
    end

    it 'finds a job by uuid or granblue_id' do
      job = create(:job)
      expect(Job.find_by_route_id(job.id)).to eq(job)
      expect(Job.find_by_route_id(job.granblue_id)).to eq(job)
      expect(Job.find_by_route_id('')).to be_nil
    end
  end
end
