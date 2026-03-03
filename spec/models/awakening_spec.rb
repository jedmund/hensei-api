# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Awakening, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:weapon_awakenings).with_foreign_key(:awakening_id) }
    it { is_expected.to have_many(:weapons).through(:weapon_awakenings) }
  end
end
