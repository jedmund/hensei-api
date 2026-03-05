# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PreviewService::Grid do
  let(:grid) { described_class.new }

  describe '#calculate_layout' do
    let(:layout) { grid.calculate_layout(canvas_height: 600, title_bottom_y: 50) }

    it 'returns all required layout keys' do
      expected_keys = %i[
        cell_width cell_height grid_total_width grid_total_height
        total_width grid_columns grid_start_y mainhand_width mainhand_height
      ]
      expect(layout.keys).to match_array(expected_keys)
    end

    it 'uses 3 grid columns (4 total minus mainhand)' do
      expect(layout[:grid_columns]).to eq(3)
    end

    it 'scales grid cells from natural dimensions' do
      expect(layout[:cell_width]).to eq((280 * 0.75).floor)
      expect(layout[:cell_height]).to eq((160 * 0.75).floor)
    end

    it 'scales mainhand to match grid height' do
      grid_height = layout[:cell_height] * 3 + 8 * 2 # 3 rows + 2 gaps
      expect(layout[:mainhand_height]).to eq(grid_height)
    end

    it 'centers grid vertically in canvas' do
      expected_y = (600 - layout[:grid_total_height]) / 2
      expect(layout[:grid_start_y]).to eq(expected_y)
    end

    it 'calculates total width as mainhand + gap + grid' do
      expected = layout[:mainhand_width] + 8 + layout[:grid_total_width]
      expect(layout[:total_width]).to eq(expected)
    end
  end

  describe '#grid_position' do
    let(:layout) { grid.calculate_layout(canvas_height: 600, title_bottom_y: 50) }

    it 'positions mainhand at left edge centered horizontally' do
      pos = grid.grid_position('mainhand', 0, layout)
      expected_x = (PreviewService::Canvas::PREVIEW_WIDTH - layout[:total_width]) / 2
      expect(pos[:x]).to eq(expected_x)
      expect(pos[:y]).to eq(layout[:grid_start_y])
    end

    it 'positions first weapon at top-left of grid' do
      pos = grid.grid_position('weapon', 0, layout)
      mainhand_x = (PreviewService::Canvas::PREVIEW_WIDTH - layout[:total_width]) / 2

      expect(pos[:x]).to eq(mainhand_x + layout[:mainhand_width] + 8)
      expect(pos[:y]).to eq(layout[:grid_start_y])
      expect(pos[:width]).to eq(layout[:cell_width])
      expect(pos[:height]).to eq(layout[:cell_height])
    end

    it 'wraps weapons to next row after 3 columns' do
      pos = grid.grid_position('weapon', 3, layout)
      # idx 3 should be row 1, col 0
      expect(pos[:y]).to eq(layout[:grid_start_y] + layout[:cell_height] + 8)
    end
  end
end
