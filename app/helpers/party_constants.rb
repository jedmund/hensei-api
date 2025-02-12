# frozen_string_literal: true
#
# This module contains shared constants used for querying and filtering Party resources.
# It is included by controllers and concerns that require these configuration values.
#
module PartyConstants
  COLLECTION_PER_PAGE = 15
  DEFAULT_MIN_CHARACTERS = 3
  DEFAULT_MIN_SUMMONS = 2
  DEFAULT_MIN_WEAPONS = 5
  MAX_CHARACTERS = 5
  MAX_SUMMONS = 8
  MAX_WEAPONS = 13
  DEFAULT_MAX_CLEAR_TIME = 5400
end
