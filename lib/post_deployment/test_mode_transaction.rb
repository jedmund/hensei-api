# frozen_string_literal: true

module PostDeployment
  class TestModeTransaction
    def initialize
      @changes = []
    end

    def add_change(model:, attributes:, operation:)
      @changes << {
        model: model,
        attributes: attributes,
        operation: operation
      }
    end

    def rollback
      @changes.clear
    end

    def committed_changes
      @changes
    end
  end
end
