# frozen_string_literal: true

# Adds an optional S3 key for tier icons. Canonical objects live at
# images/difficulties/<id>.png. The DraftWorkspace stages uploads at
# images/difficulties/_drafts/<draft_id>.png; the drafts prefix should
# have an S3 lifecycle rule (e.g. 30-day expiry) to clean up orphans
# from abandoned drafts that never reach commit or discard.
class AddImageKeyToDifficulties < ActiveRecord::Migration[8.0]
  def change
    add_column :difficulties, :image_key, :string
  end
end
