# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin jobs schema', type: :request do
  it_behaves_like 'an admin schema', 'jobs', Api::V1::JobsController, :job_update_params
end
