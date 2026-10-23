# frozen_string_literal: true

module Granblue
  class WikiError < StandardError
    attr_reader :code, :page

    def initialize(code: nil, page: nil, message: nil)
      super(message)
      @code = code
      @page = page
    end

    def to_hash
      {
        message: message,
        code: code,
        page: page
      }
    end
  end
end
