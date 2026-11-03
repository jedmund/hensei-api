require 'rails_helper'

RSpec.describe Api::V1::ErrorBlueprint do
  def render(**)
    described_class.render_as_hash(nil, **)
  end

  it 'renders the error option under error' do
    error = { message: 'Object could not be found', code: 'not_found' }

    expect(render(error: error)).to eq(error: error)
  end

  it 'renders the errors option under errors' do
    errors = { base: ['changed at the same time; try again'] }

    expect(render(errors: errors)).to eq(errors: errors)
  end

  it 'renders both when both are given' do
    expect(render(error: { code: 'a' }, errors: { base: ['b'] }))
      .to eq(error: { code: 'a' }, errors: { base: ['b'] })
  end

  it 'renders an empty object with no options' do
    expect(render).to eq({})
  end

  it 'ignores options it has no field for' do
    expect(render(exception: 'boom')).to eq({})
  end
end
