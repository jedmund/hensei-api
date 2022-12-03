module Api::V1
  class NoJobSkillProvidedError < StandardError
    def http_status
      422
    end

    def code
      "no_job_skill_provided"
    end

    def message
      "A job skill ID must be provided"
    end

    def to_hash
      {
        message: message,
        code: code
      }
    end
  end
end
