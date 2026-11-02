# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin character roles schema', type: :request do
  it_behaves_like 'an admin schema', 'character_roles', Api::V1::GridCharacterRolesController, :role_params
end
