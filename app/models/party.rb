class Party < ApplicationRecord
##### ActiveRecord Associations
    belongs_to :user, optional: true
    has_many :weapons, through: :grid_weapons
end
