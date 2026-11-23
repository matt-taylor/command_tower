# frozen_string_literal: true

module CommandTower
  module UI
    module Nodes
      # Sensitive node (a check-in code). `value` is excluded from derived text,
      # legacy mapping and email, and never appears in `inspect`, `to_s`, `pp`,
      # validation errors or logs. The wire form (`as_json`) is the one place it
      # is emitted, because the client renders it. Validation adds error types
      # only, never a `value:` option.
      class Code < Node
        TYPE = "code"
        FORMAT = %w[qr text].freeze

        field :value, :string
        field :format, :string
        field :label, :string

        validates :value, :label, presence: true
        validates :format, inclusion: { in: FORMAT }

        def inspect
          "#<#{self.class.name} value=[REDACTED]>"
        end
      end
    end
  end
end
