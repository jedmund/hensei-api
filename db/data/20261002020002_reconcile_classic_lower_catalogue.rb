# frozen_string_literal: true

require Rails.root.join('lib/granblue/classic_lower_catalogue')

class ReconcileClassicLowerCatalogue < ActiveRecord::Migration[8.0]
  def up
    Granblue::ClassicLowerCatalogue.new.apply!
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Previous shared pool memberships vary; restore a reviewed backup.'
  end
end
