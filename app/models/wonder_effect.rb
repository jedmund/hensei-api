# frozen_string_literal: true

##
# An effect line of a fixed Wonder, in the game's text. action_id is the
# game's effect id and is shared between Wonders with the same effect; it's
# nil for effects known only from the wiki. details holds wiki values for a
# later damage calculation (e.g. Eternals' HP and ATK); it isn't displayed.
class WonderEffect < ApplicationRecord
  has_many :wonder_effect_links, dependent: :restrict_with_error
  has_many :wonders, through: :wonder_effect_links

  validates :action_id, uniqueness: true, allow_nil: true
end
