# frozen_string_literal: true

namespace :granblue do
  desc 'Read-only preflight for the supplied banner catalogue reconciliation'
  task preview_banner_catalogue: :environment do
    require Rails.root.join('lib/granblue/banner_catalogue_reconciliation')
    puts JSON.pretty_generate(Granblue::BannerCatalogueReconciliation.new.preview)
  end
end

namespace :granblue do
  desc 'Read-only preflight for verified Classic lower-rarity shared membership'
  task preview_classic_lower_catalogue: :environment do
    require Rails.root.join('lib/granblue/classic_lower_catalogue')
    puts JSON.pretty_generate(Granblue::ClassicLowerCatalogue.new.preview)
  end
end
