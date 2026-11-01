# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PartyDifficulty::Rules do
  describe '.validate_params' do
    let(:base) { { 'slugs' => ['grand'], 'scale_by_count' => true, 'max_count' => 3 } }

    it 'accepts a growth_ratio of at least 1' do
      expect(described_class.validate_params('character_series_match', base.merge('growth_ratio' => 2))).to be_empty
      expect(described_class.validate_params('character_series_match', base.merge('growth_ratio' => '1.5'))).to be_empty
    end

    it 'rejects a growth_ratio below 1 or that is not a number' do
      expect(described_class.validate_params('character_series_match', base.merge('growth_ratio' => 0.5)))
        .to include('growth_ratio must be at least 1')
      expect(described_class.validate_params('character_series_match', base.merge('growth_ratio' => 'fast')))
        .to include('growth_ratio must be a number')
    end
  end
end
