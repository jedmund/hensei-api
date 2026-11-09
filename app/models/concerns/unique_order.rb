# frozen_string_literal: true

# Keeps each record's order unique within its table. A moved record takes its new
# position and the records it passes each shift one place to fill the gap it left.
module UniqueOrder
  extend ActiveSupport::Concern

  included do
    before_save :make_room_for_order, if: -> { new_record? || order_changed? }
  end

  private

  def make_room_for_order
    if new_record?
      shift_order(self.class.where(order: order..), 1) if self.class.exists?(order: order)
    elsif order > order_in_database
      shift_order(self.class.where(order: (order_in_database + 1)..order), -1)
    else
      shift_order(self.class.where(order: order...order_in_database), 1)
    end
  end

  # update_all skips callbacks, so these shifts don't cascade
  def shift_order(records, by)
    records.update_all(['"order" = "order" + ?, updated_at = ?', by, Time.current])
  end
end
