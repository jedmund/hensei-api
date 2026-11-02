# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin bullets schema', type: :request do
  it_behaves_like 'an admin schema', 'bullets', Api::V1::BulletsController, :bullet_params
end
