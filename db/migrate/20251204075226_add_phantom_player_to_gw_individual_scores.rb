class AddPhantomPlayerToGwIndividualScores < ActiveRecord::Migration[8.0]
  def change
    add_reference :gw_individual_scores, :phantom_player, foreign_key: true, type: :uuid
  end
end
