class Party < ApplicationRecord
##### ActiveRecord Associations
    belongs_to :user, optional: true
    belongs_to :raid, optional: true
    has_many :characters, foreign_key: "party_id", class_name: "GridCharacter", dependent: :destroy
    has_many :weapons, foreign_key: "party_id", class_name: "GridWeapon", dependent: :destroy
    has_many :summons, foreign_key: "party_id", class_name: "GridSummon", dependent: :destroy
end