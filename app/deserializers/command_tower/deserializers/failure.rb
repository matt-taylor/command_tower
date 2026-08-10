# frozen_string_literal: true

module CommandTower
  module Deserializers
    module Failure
      module_function

      def build(code:, field: nil, details: {})
        entry = { code: code.to_s, field: field&.to_s, details: details || {} }
        entry
      end
    end
  end
end
