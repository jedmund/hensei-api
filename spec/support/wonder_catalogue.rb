# frozen_string_literal: true

# Helpers for Wonders specs: the real catalogue (loaded through its data
# migration, inside the example's transaction) and the game captures.
module WonderCatalogueHelpers
  def seed_wonder_catalogue!
    require Rails.root.join('db/data/20261121110000_load_wonder_catalogue').to_s unless defined?(LoadWonderCatalogue)
    LoadWonderCatalogue.load!
  end

  def wonder_capture(name)
    JSON.parse(Rails.root.join('spec/fixtures/wonders', "memorial_list.#{name}.json").read)
  end

  # item_id => item over a capture's categories
  def wonder_capture_items(name)
    wonder_capture(name).flat_map { |category| category['item'] }.index_by { |item| item['item_id'] }
  end
end

RSpec.configure do |config|
  config.include WonderCatalogueHelpers
end
