# frozen_string_literal: true

module Granblue
  class WikiError < StandardError
    def initialize(code: nil, page: nil, message: nil)
      super
      @code = code
      @page = page
      @message = message
    end

    def to_hash
      {
        message: @message,
        code: @code,
        page: @page
      }
    end
  end
end
