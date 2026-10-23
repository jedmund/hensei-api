# frozen_string_literal: true

require 'rails_helper'

# A style shift shares its base character's granblue_id but owns its own skills:
# every view that serializes a character's skills must use the row it was handed.
RSpec.describe 'Character skills per style shift', type: :request do
  let!(:base) { create(:character, granblue_id: '3040377000', name_en: 'Cidala') }
  let!(:style) do
    create(:character, granblue_id: '3040377000', name_en: 'Cidala', style_swap: true, style_name_en: 'Super Cidala')
  end

  def give_ability(character, name, game_icon)
    skill = create(:character_skill, character: character, kind: :ability, position: 1)
    create(:character_skill_version, character_skill: skill, name_en: name, game_icon: game_icon, ordinal: 1)
  end

  def ability_names(skills_json)
    skills_json.flat_map { |skill| skill['versions'].map { |v| v.dig('name', 'en') } }
  end

  before do
    give_ability(base, 'Jinx of the Tiger', '1640_1')
    give_ability(style, 'Luck Goes Up', '2559_3')
  end

  describe 'GET /api/v1/characters/:granblue_id' do
    it "returns the style row's skills with style_swap=true" do
      get "/api/v1/characters/#{base.granblue_id}", params: { style_swap: 'true' }

      expect(response).to have_http_status(:ok)
      expect(ability_names(response.parsed_body['skills'])).to eq(['Luck Goes Up'])
    end

    it "returns the base row's skills without style_swap" do
      get "/api/v1/characters/#{base.id}"

      expect(response).to have_http_status(:ok)
      expect(ability_names(response.parsed_body['skills'])).to eq(['Jinx of the Tiger'])
    end
  end

  describe 'GET /api/v1/parties/:shortcode' do
    let(:party) { create(:party, visibility: 1) }

    it "serializes a style-2 grid character with the style's skills" do
      create(:grid_character, party: party, character: style, position: 1, uncap_level: 4)

      get "/api/v1/parties/#{party.shortcode}"

      expect(response).to have_http_status(:ok)
      grid = response.parsed_body.dig('party', 'characters').find { |gc| gc['position'] == 1 }
      expect(ability_names(grid.dig('character', 'skills'))).to eq(['Luck Goes Up'])
    end
  end
end
