# frozen_string_literal: true

# Odious and Collab summon series shared an order. Odious stays where it is, and
# Collab and everything after it move back one place. Does nothing if they differ.
class OrderOdiousBeforeCollabSummonSeries < ActiveRecord::Migration[8.1]
  def up
    odious = SummonSeries.find_by(slug: 'odious')
    collab = SummonSeries.find_by(slug: 'collab')
    return unless odious && collab && odious.order == collab.order

    SummonSeries.where(order: (odious.order + 1)..).update_all(['"order" = "order" + 1, updated_at = ?', Time.current])
    collab.update!(order: odious.order + 1)
  end

  def down
    # Nothing to undo: the tie wasn't intended.
  end
end
