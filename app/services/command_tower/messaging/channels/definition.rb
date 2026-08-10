# frozen_string_literal: true

module CommandTower
  module Messaging
    module Channels
      Definition = Data.define(
        :key,
        :label,
        :kind,
        :supports_endpoint_records,
        :identity_backed,
        :canonical_provider,
      ) do
        def external?
          kind == :external
        end

        def inbox?
          kind == :inbox
        end
      end
    end
  end
end
