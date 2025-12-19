# frozen_string_literal: true

class AddExcusedToGwIndividualScores < ActiveRecord::Migration[8.0]
  def change
    add_column :gw_individual_scores, :excused, :boolean, default: false, null: false
    add_column :gw_individual_scores, :excuse_reason, :text
  end
end
