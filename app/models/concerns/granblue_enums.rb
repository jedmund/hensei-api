module GranblueEnums
  extend ActiveSupport::Concern

  # Define constants for shared enum mappings.
  RARITIES = { R: 1, SR: 2, SSR: 3 }.freeze
  # Element, proficiency and race values are the game's own numbers, so data
  # read from the game needs no conversion.
  ELEMENTS = { Null: 0, Fire: 1, Water: 2, Earth: 3, Wind: 4, Light: 5, Dark: 6 }.freeze
  GENDERS = { Unknown: 0, Male: 1, Female: 2, "Male/Female": 3 }.freeze

  # Single proficiency enum mapping used for both proficiency1 and proficiency2.
  # Matches the game's weapon kind.
  PROFICIENCY = {
    None: 0,
    Sabre: 1,
    Dagger: 2,
    Spear: 3,
    Axe: 4,
    Staff: 5,
    Gun: 6,
    Melee: 7,
    Bow: 8,
    Harp: 9,
    Katana: 10
  }.freeze

  # Single race enum mapping used for both race1 and race2. Matches the game's tribe.
  RACES = {
    Human: 1,
    Erune: 2,
    Draph: 3,
    Harvin: 4,
    Other: 5,
    Primal: 6,
    Geonoid: 7,
    Levleath: 8,
    Grokkle: 9,
    Wolvir: 10
  }.freeze

  # Lowercase element and proficiency names for Rails enums (no Null/None).
  ELEMENT_ENUM = ELEMENTS.except(:Null).transform_keys { |k| k.to_s.downcase.to_sym }.freeze
  PROFICIENCY_ENUM = PROFICIENCY.except(:None).transform_keys { |k| k.to_s.downcase.to_sym }.freeze

  # Character seasons - display disambiguation for seasonal variants (e.g., "Vane [Halloween]")
  # If no season, value should be nil (not a default value)
  CHARACTER_SEASONS = {
    Valentine: 1,
    Formal: 2,
    Summer: 3,
    Halloween: 4,
    Holiday: 5
  }.freeze

  # Character series - represents character identity/pool membership (can have multiple)
  CHARACTER_SERIES = {
    Standard: 1,
    Grand: 2,
    Zodiac: 3,
    Promo: 4,
    Collab: 5,
    Eternal: 6,
    Evoker: 7,
    Saint: 8,
    Fantasy: 9,
    Summer: 10,
    Yukata: 11,
    Valentine: 12,
    Halloween: 13,
    Formal: 14,
    Holiday: 15,
    Event: 16
  }.freeze

  # Bullet types - slot types for gun-proficiency weapons
  BULLET_TYPES = {
    Parabellum: 1,
    Rifle: 2,
    Cartridge: 3,
    Aetherial: 4
  }.freeze

  # Gacha promotions - which pools/banners a weapon or summon appears in
  PROMOTIONS = {
    Premium: 1,
    Classic: 2,
    ClassicII: 3,
    Flash: 4,
    Legend: 5,
    Valentine: 6,
    Summer: 7,
    Halloween: 8,
    Holiday: 9,
    Collab: 10,
    Formal: 11,
    ClassicIII: 12
  }.freeze
end
