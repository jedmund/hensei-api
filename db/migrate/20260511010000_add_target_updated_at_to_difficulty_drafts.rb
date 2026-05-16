class AddTargetUpdatedAtToDifficultyDrafts < ActiveRecord::Migration[8.0]
  def change
    # Captures the target row's updated_at at stage time so commit! can detect
    # concurrent edits to the same target by another editor (optimistic
    # concurrency). Nullable because create drafts have no target, and rows
    # staged before this migration won't have a snapshot.
    add_column :difficulty_drafts, :target_updated_at, :datetime
  end
end
