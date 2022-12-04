module Api::V1
  class NoJobProvidedError < GranblueError
    def http_status
      422
    end

    def code
      "no_job_provided"
    end

    def message
      "A job ID must be provided"
    end

    def to_hash
      {
        message: message,
        code: code
      }
    end
  end
end
