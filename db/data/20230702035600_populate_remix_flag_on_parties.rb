# frozen_string_literal: true

class PopulateRemixFlagOnParties < ActiveRecord::Migration[7.0]
  def up
    Party.find_each do |party|
      party.update(remix: party.source_party_id.present?)
    end
  end

  def down
    Party.find_each do |party|
      party.update(remix: false)
    end
  end
end
