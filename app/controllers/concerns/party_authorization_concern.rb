# frozen_string_literal: true

module PartyAuthorizationConcern
  extend ActiveSupport::Concern

  # Checks whether the current user (or provided edit key) is authorized to modify @party.
  def authorize_party!
    return render_not_found_response('party') unless @party

    if @party.user.present?
      render_unauthorized_response unless current_user.present? && @party.user == current_user
    else
      render_unauthorized_response unless @party.edit_key_matches?(edit_key)
    end
  end

  alias authorize_party_edit! authorize_party!

  # Returns true if the party does not belong to the current user.
  def not_owner?
    if @party.user
      return true if current_user && @party.user != current_user
      return true if current_user.nil? && edit_key.present?
    else
      return true if current_user.present?
      return true if current_user.nil? && (@party.edit_key != edit_key)
    end
    false
  end
end
