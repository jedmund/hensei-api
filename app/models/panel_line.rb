# frozen_string_literal: true

# One row per panel display line: which boost_type (and series split) renders where,
# with what label and badge. Rows override PanelPresenter::LINES; an empty table
# falls back to the code default (so tests and bare databases still work).
class PanelLine < ApplicationRecord
  validates :boost_type, presence: true, uniqueness: { scope: :series }
  validates :label_en, :slug, :group_name, presence: true
  validates :position, presence: true, numericality: { only_integer: true }
end
