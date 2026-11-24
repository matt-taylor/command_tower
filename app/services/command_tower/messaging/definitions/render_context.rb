# frozen_string_literal: true

module CommandTower
  module Messaging
    module Definitions
      # Input to every MessageDefinition composer (inbox, email, facts, slots). Composers receive
      # this value, never an ActiveRecord row, so Accept, Deliver, the inbox read and the gallery
      # all run the same pure code path. `slots` is nil until Accept has resolved them.
      RenderContext = Data.define(
        :notification_type_key,
        :metadata,
        :metadata_version,
        :slots,
        :render_zone
      )
    end
  end
end
