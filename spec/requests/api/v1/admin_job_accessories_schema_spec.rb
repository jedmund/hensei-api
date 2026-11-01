# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin job accessories schema', type: :request do
  it_behaves_like 'an admin schema', 'job_accessories', Api::V1::JobAccessoriesController, :job_accessory_params
end
