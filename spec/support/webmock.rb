# frozen_string_literal: true

require 'webmock/rspec'

# No spec reaches the network. webmock/rspec enables WebMock with every real
# connection blocked; a spec that loosens that (disable!, allow_net_connect!)
# restores it when it finishes, and this hook restores it again after every
# example, so a spec can't leave the network open for the ones that run after it.
RSpec.configure do |config|
  config.after do
    WebMock.enable!
    WebMock.disable_net_connect!
  end
end
