class Party < ApplicationRecord
##### ActiveRecord Associations
    belongs_to :user, optional: true
    has_many :characters, foreign_key: "party_id", class_name: "GridCharacter"
    has_many :weapons, foreign_key: "party_id", class_name: "GridWeapon"
    has_many :summons, foreign_key: "party_id", class_name: "GridSummon"
end