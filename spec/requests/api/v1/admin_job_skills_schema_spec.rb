# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin job skills schema', type: :request do
  it_behaves_like 'an admin schema', 'job_skills', Api::V1::JobSkillsController, :job_skill_params
end
