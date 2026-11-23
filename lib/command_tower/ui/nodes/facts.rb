# frozen_string_literal: true

module CommandTower
  module UI
    module Nodes
      # Structural wrapper for the shared fact block so renderers and checks can
      # find it. Renders as a plain stack. Capped by Limits::MAX_FACTS_NODES
      # descendants (enforced by Document).
      class Facts < Container
        TYPE = "facts"
      end
    end
  end
end
