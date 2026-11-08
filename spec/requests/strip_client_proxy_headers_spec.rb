require 'rails_helper'

RSpec.describe 'Client-supplied proxy headers', type: :request do
  let(:forwarded_for) { '172.69.214.148, 79.127.177.114' }

  it 'ignores a Forwarded header that disagrees with X-Forwarded-For' do
    get '/api/v1/version', headers: { 'Forwarded' => 'for=10.73.231.58', 'X-Forwarded-For' => forwarded_for }
    expect(response).to have_http_status(:ok)
    expect(request.remote_ip).to eq('79.127.177.114')
  end

  it 'ignores a Client-Ip header that disagrees with X-Forwarded-For' do
    get '/api/v1/version', headers: { 'Client-Ip' => '203.0.113.9', 'X-Forwarded-For' => forwarded_for }
    expect(response).to have_http_status(:ok)
    expect(request.remote_ip).to eq('79.127.177.114')
  end
end
