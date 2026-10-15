# frozen_string_literal: true

# Marks the curation overlay (the per-series files in data/weapon_skill_curation/) dirty
# when a curated row changes, so the development auto-export
# (Granblue::CurationAutoExport) picks it up. A row counts as curated when its stamp
# column is set now or was set before this change.
module CurationExportTracking
  extend ActiveSupport::Concern

  included do
    class_attribute :curation_stamp_column, default: :manually_edited_at
    after_commit :mark_curation_dirty
  end

  private

  def mark_curation_dirty
    column = curation_stamp_column.to_s
    stamped = self[column].present? || previous_changes[column]&.first.present?
    Granblue::CurationAutoExport.mark_dirty! if stamped
  end
end
