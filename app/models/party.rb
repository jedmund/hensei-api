class Party < ApplicationRecord
##### ActiveRecord Associations
    belongs_to :user, optional: true
    has_many :weapons, foreign_key: "party_id", class_name: "GridWeapon"
end