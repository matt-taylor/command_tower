# frozen_string_literal: true

require "command_tower/schema/shared/inbox/modified"

module CommandTower
  module Schema
    module Inbox
      module Messages
        module Ack
          class Response < JsonSchematize::Generator
            # Response is the Shared::Inbox::Modified schema
            # We'll use it directly in the controller
          end
        end
      end
    end
  end
end
