# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Job, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:skills).class_name('JobSkill') }
    it { is_expected.to belong_to(:base_job).class_name('Job').optional }
  end
end
