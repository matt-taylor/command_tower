# frozen_string_literal: true

module CommandTower
  module UI
    module RequiredFacts
      module Matchers
        # Passes when the metadata value for `key` appears verbatim in the text.
        # Host matcher protocol: `call(text:, metadata:, t:) -> Boolean`.
        class Text
          def initialize(key:)
            @key = key.to_s
          end

          def call(text:, metadata:, **)
            value = Verdict.fetch(metadata, @key)
            !value.nil? && text.to_s.include?(value.to_s)
          end
        end
      end
    end
  end
end
