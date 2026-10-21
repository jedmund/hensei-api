# frozen_string_literal: true

# Status names resolve through gbf.wiki's Module:StatusList (data/wiki/status_list.lua) first.
# Specs run with an empty list so they exercise the fallbacks, unless tagged :status_list (the
# committed list: goldens, StatusList specs).
RSpec.configure do |config|
  config.before do |example|
    if example.metadata[:status_list]
      Granblue::Parsers::StatusList.reset!
    else
      Granblue::Parsers::StatusList.use
    end
  end
  config.after { Granblue::Parsers::StatusList.reset! }
end
