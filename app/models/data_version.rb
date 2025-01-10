# frozen_string_literal: true
class DataVersion < ActiveRecord::Base
  validates :filename, presence: true, uniqueness: true
  validates :imported_at, presence: true

  def self.mark_as_imported(filename)
    create!(filename: filename, imported_at: Time.current)
  end

  def self.imported?(filename)
    exists?(filename: filename)
  end
end
