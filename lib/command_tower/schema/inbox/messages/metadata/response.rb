# frozen_string_literal: true

require "command_tower/schema/shared/inbox/metadata"

module CommandTower
  module Schema
    module Inbox
      module Messages
        module Metadata
          class Response < JsonSchematize::Generator
            # Response is the Shared::Inbox::Metadata schema
            # We'll use it directly in the controller
          end
        end
      end
    end
  end
end
