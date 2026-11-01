# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobSkill, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:job) }
  end

  describe 'equality' do
    it 'considers two job skills with the same id as equal' do
      skill = create(:job_skill)
      expect(skill).to eq(skill)
    end

    it 'considers two different job skills as not equal' do
      a = create(:job_skill)
      b = create(:job_skill)
      expect(a).not_to eq(b)
    end
  end

  describe 'validations' do
    it 'requires a kebab-case slug, unique per job' do
      skill = create(:job_skill, slug: 'rage')
      expect(build(:job_skill, slug: 'Rage IV')).not_to be_valid
      expect(build(:job_skill, slug: nil)).not_to be_valid
      expect(build(:job_skill, job: skill.job, slug: 'rage')).not_to be_valid
      expect(build(:job_skill, slug: 'rage')).to be_valid
    end

    it 'requires both names, a job and a known colour' do
      expect(build(:job_skill, name_jp: '')).not_to be_valid
      expect(build(:job_skill, job: nil)).not_to be_valid
      expect(build(:job_skill, color: 5)).not_to be_valid
    end

    it 'accepts only non-negative orders and positive action ids' do
      expect(build(:job_skill, order: -1)).not_to be_valid
      expect(build(:job_skill, action_id: 0)).not_to be_valid
      expect(build(:job_skill, action_id: 203_921)).to be_valid
    end
  end
end
