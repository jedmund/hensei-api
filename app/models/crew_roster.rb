# frozen_string_literal: true

class CrewRoster < ApplicationRecord
  belongs_to :crew
  belongs_to :created_by, class_name: 'User'

  validates :name, presence: true, length: { maximum: 100 }
  validates :element, presence: true, inclusion: { in: 1..6 }
  validates :element, uniqueness: { scope: :crew_id }
  validate :items_must_be_valid_array

  # Ensure items is always an array
  after_initialize do
    self.items ||= []
  end

  ELEMENT_NAMES = {
    1 => 'Wind',
    2 => 'Fire',
    3 => 'Water',
    4 => 'Earth',
    5 => 'Dark',
    6 => 'Light'
  }.freeze

  def self.seed_for_crew!(crew, user)
    ELEMENT_NAMES.each do |element, name|
      crew.crew_rosters.find_or_create_by!(element: element) do |roster|
        roster.name = name
        roster.created_by = user
        roster.items = []
      end
    end
  end

  private

  def items_must_be_valid_array
    return if items.is_a?(Array) && items.all? { |i| i.is_a?(Hash) && i['id'].present? && i['type'].present? }
    return if items.is_a?(Array) && items.empty?

    errors.add(:items, 'must be an array of {id, type} objects')
  end
end
