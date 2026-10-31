# frozen_string_literal: true

# Unique viewers of a party on one UTC day. Written only by
# PartyViews::FlushJob; never exposed in a response.
class PartyViewDay < ApplicationRecord
  belongs_to :party
end
