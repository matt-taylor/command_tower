# frozen_string_literal: true

module CommandTower
  module Deserializers
    module Messaging
      module Preferences
        class ShowDeserializer < CommandTower::Deserializers::ApplicationDeserializer
          Input = Data.define

          def call(_params)
            success(Input.new)
          end
        end
      end
    end
  end
end
