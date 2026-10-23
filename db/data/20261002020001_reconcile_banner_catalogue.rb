# frozen_string_literal: true

require Rails.root.join('lib/granblue/banner_catalogue_reconciliation')

class ReconcileBannerCatalogue < ActiveRecord::Migration[8.0]
  def up
    Granblue::BannerCatalogueReconciliation.new.apply!
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Catalogue rows may be referenced by user collections; restore a reviewed backup.'
  end
end
