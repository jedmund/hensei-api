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
end
