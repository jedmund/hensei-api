class SetPreviewStateDefaultToPending < ActiveRecord::Migration[8.0]
  def up
    Party.where(preview_state: nil).find_each do |party|
      party.update_column(:preview_state, :pending)
    end
  end
end
