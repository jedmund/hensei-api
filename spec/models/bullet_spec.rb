# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Bullet, type: :model do
  describe 'validations' do
    it 'accepts the factory' do
      expect(build(:bullet)).to be_valid
    end

    it 'requires a five-digit granblue_id, unique' do
      bullet = create(:bullet, granblue_id: '90101')
      expect(build(:bullet, granblue_id: nil)).not_to be_valid
      expect(build(:bullet, granblue_id: '9010')).not_to be_valid
      expect(build(:bullet, granblue_id: '901011')).not_to be_valid
      expect(build(:bullet, granblue_id: '9010a')).not_to be_valid
      expect(build(:bullet, granblue_id: bullet.granblue_id)).not_to be_valid
    end

    it 'requires a kebab-case slug, unique' do
      bullet = create(:bullet, slug: 'iron-bullet')
      expect(build(:bullet, slug: '')).not_to be_valid
      expect(build(:bullet, slug: 'Iron Bullet')).not_to be_valid
      expect(build(:bullet, slug: 'iron--bullet')).not_to be_valid
      expect(build(:bullet, slug: bullet.slug)).not_to be_valid
    end

    it 'requires an English name and a known type' do
      expect(build(:bullet, name_en: '')).not_to be_valid
      expect(build(:bullet, name_jp: nil)).to be_valid
      expect(build(:bullet, bullet_type: 0)).not_to be_valid
      expect(build(:bullet, bullet_type: 5)).not_to be_valid
      expect(build(:bullet, bullet_type: 4)).to be_valid
    end

    it 'takes whole numbers of at least zero for ATK and order' do
      expect(build(:bullet, atk: -1)).not_to be_valid
      expect(build(:bullet, atk: 1.5)).not_to be_valid
      expect(build(:bullet, order: -1)).not_to be_valid
      expect(build(:bullet, atk: 0, order: 0)).to be_valid
    end
  end
end
