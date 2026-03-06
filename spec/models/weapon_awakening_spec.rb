# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WeaponAwakening, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:weapon) }
    it { is_expected.to belong_to(:awakening) }
  end
end
