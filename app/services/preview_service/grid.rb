# app/services/grid.rb
module PreviewService
  class Grid
    GRID_GAP = 8
    GRID_COLUMNS = 4
    GRID_ROWS = 3
    GRID_SCALE = 0.75 # Scale for grid images

    # Natural dimensions
    MAINHAND_NATURAL_WIDTH = 200
    MAINHAND_NATURAL_HEIGHT = 420

    GRID_NATURAL_WIDTH = 280
    GRID_NATURAL_HEIGHT = 160

    # Scaled grid dimensions
    CELL_WIDTH = (GRID_NATURAL_WIDTH * GRID_SCALE).floor
    CELL_HEIGHT = (GRID_NATURAL_HEIGHT * GRID_SCALE).floor

    def calculate_layout(canvas_height:, title_bottom_y:, padding: 24)
      # Use scaled dimensions for grid images
      cell_width = CELL_WIDTH
      cell_height = CELL_HEIGHT

      grid_columns = GRID_COLUMNS - 1 # 3 columns for grid items
      grid_total_width = cell_width * grid_columns + GRID_GAP * (grid_columns - 1)
      grid_total_height = cell_height * GRID_ROWS + GRID_GAP * (GRID_ROWS - 1)

      # Determine the scale factor for the mainhand to match grid height
      mainhand_scale = grid_total_height.to_f / MAINHAND_NATURAL_HEIGHT
      scaled_mainhand_width = (MAINHAND_NATURAL_WIDTH * mainhand_scale).floor
      scaled_mainhand_height = (MAINHAND_NATURAL_HEIGHT * mainhand_scale).floor

      total_width = scaled_mainhand_width + GRID_GAP + grid_total_width

      # Center the grid absolutely in the canvas
      grid_start_y = (canvas_height - grid_total_height) / 2

      {
        cell_width: cell_width,
        cell_height: cell_height,
        grid_total_width: grid_total_width,
        grid_total_height: grid_total_height,
        total_width: total_width,
        grid_columns: grid_columns,
        grid_start_y: grid_start_y,
        mainhand_width: scaled_mainhand_width,
        mainhand_height: scaled_mainhand_height
      }
    end

    def grid_position(type, idx, layout)
      case type
      when 'mainhand'
        {
          x: (Canvas::PREVIEW_WIDTH - layout[:total_width]) / 2,
          y: layout[:grid_start_y]
          # No explicit width/height here since resizing is handled in draw_grid_item
        }
      when 'weapon'
        row = idx / layout[:grid_columns]
        col = idx % layout[:grid_columns]
        {
          x: (Canvas::PREVIEW_WIDTH - layout[:total_width]) / 2 + layout[:mainhand_width] + GRID_GAP + col * (layout[:cell_width] + GRID_GAP),
          y: layout[:grid_start_y] + row * (layout[:cell_height] + GRID_GAP),
          width: layout[:cell_width],
          height: layout[:cell_height]
        }
      end
    end

    def draw_grid_item(image, item_image, type, idx, layout)
      coords = grid_position(type, idx, layout)

      if type == 'mainhand'
        # Resize mainhand using scaled dimensions from layout
        item_image.resize "#{layout[:mainhand_width]}x#{layout[:mainhand_height]}"
        item_image = round_corners(item_image, 4)
      else
        # Resize grid items to fixed, scaled dimensions and round corners
        item_image.resize "#{coords[:width]}x#{coords[:height]}^"
        item_image = round_corners(item_image, 4)
      end

      image.composite(item_image) do |c|
        c.compose "Over"
        c.geometry "+#{coords[:x]}+#{coords[:y]}"
      end
    end

    def round_corners(image, radius = 8)
      # Create a round-corner mask for the image
      mask = MiniMagick::Image.open(image.path)
      mask.format "png"
      mask.combine_options do |m|
        m.alpha "transparent"
        m.background "none"
        m.fill "white"
        m.draw "roundRectangle 0,0,#{mask.width},#{mask.height},#{radius},#{radius}"
      end

      image.composite(mask) do |c|
        c.compose "DstIn"
      end
    end
  end
end
