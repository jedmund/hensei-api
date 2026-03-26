# frozen_string_literal: true

##
# Shared mapping for forged Arcarum summon IDs.
# Forged (evolved) Arcarum summons use different master IDs in the game API
# than the base SSR IDs stored in the database.
#
module SummonIdMapping
  FORGED_ARCARUM_IDS = {
    '2040313000' => '2040236000', # Justice
    '2040314000' => '2040237000', # The Hanged Man
    '2040315000' => '2040238000', # Death
    '2040316000' => '2040239000', # Temperance
    '2040317000' => '2040240000', # The Devil
    '2040318000' => '2040241000', # The Tower
    '2040319000' => '2040242000', # The Star
    '2040320000' => '2040243000', # The Moon
    '2040321000' => '2040244000', # The Sun
    '2040322000' => '2040245000'  # Judgement
  }.freeze

  # Resolves a forged Arcarum summon ID to its base SSR ID.
  # Returns the input unchanged if it's not a forged ID.
  def self.resolve(id)
    id_str = id.to_s
    FORGED_ARCARUM_IDS[id_str] || id_str
  end
end
