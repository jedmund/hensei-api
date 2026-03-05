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
end
