module GranblueEnums
  extend ActiveSupport::Concern

  # Define constants for shared enum mappings.
  RARITIES = { R: 1, SR: 2, SSR: 3 }.freeze
  ELEMENTS = { Null: 0, Wind: 1, Fire: 2, Water: 3, Earth: 4, Dark: 5, Light: 6 }.freeze
  GENDERS = { Unknown: 0, Male: 1, Female: 2, "Male/Female": 3 }.freeze

  # Single proficiency enum mapping used for both proficiency1 and proficiency2.
  PROFICIENCY = {
    None: 0,
    Sabre: 1,
    Dagger: 2,
    Axe: 3,
    Spear: 4,
    Bow: 5,
    Staff: 6,
    Melee: 7,
    Harp: 8,
    Gun: 9,
    Katana: 10
  }.freeze

  # Single race enum mapping used for both race1 and race2.
  RACES = {
    Unknown: 0,
    Human: 1,
    Erune: 2,
    Draph: 3,
    Harvin: 4,
    Primal: 5,
    None: 6
  }.freeze

  # Character seasons - represents gacha availability window (when you can pull)
  CHARACTER_SEASONS = {
    Standard: 1,
    Valentine: 2,
    Formal: 3,
    Summer: 4,
    Halloween: 5,
    Holiday: 6
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
    Event: 15
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
    Formal: 11
  }.freeze
end
