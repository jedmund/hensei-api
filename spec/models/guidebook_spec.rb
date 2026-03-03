# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Guidebook, type: :model do
  describe 'equality' do
    it 'considers two guidebooks with the same granblue_id as equal' do
      a = build(:guidebook, granblue_id: '12345')
      b = build(:guidebook, granblue_id: '12345')
      expect(a).to eq(b)
    end

    it 'considers two guidebooks with different granblue_ids as not equal' do
      a = build(:guidebook, granblue_id: '12345')
      b = build(:guidebook, granblue_id: '67890')
      expect(a).not_to eq(b)
    end

    it 'is not equal to a different class' do
      guidebook = build(:guidebook)
      expect(guidebook).not_to eq('not a guidebook')
    end
  end
end
