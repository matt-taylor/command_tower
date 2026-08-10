# frozen_string_literal: true

module CommandTower
  module Deserializers
    module Clients
      # Sentinel for "key absent from provider payload" — distinct from explicit nil.
      Missing = Object.new.freeze
    end
  end
end
