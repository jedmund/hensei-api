# frozen_string_literal: true

module PartyAuthorizationConcern
  extend ActiveSupport::Concern

  # Checks whether the current user (or provided edit key) is authorized to modify @party.
  def authorize_party!
    if @party.user.present?
      render_unauthorized_response unless current_user.present? && @party.user == current_user
    else
      provided_edit_key = edit_key.to_s.strip.force_encoding('UTF-8')
      party_edit_key = @party.edit_key.to_s.strip.force_encoding('UTF-8')
      render_unauthorized_response unless valid_edit_key?(provided_edit_key, party_edit_key)
    end
  end

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

  # Verifies that the provided edit key matches the party's edit key.
  def valid_edit_key?(provided_edit_key, party_edit_key)
    provided_edit_key.present? &&
      provided_edit_key.bytesize == party_edit_key.bytesize &&
      ActiveSupport::SecurityUtils.secure_compare(provided_edit_key, party_edit_key)
  end
end
