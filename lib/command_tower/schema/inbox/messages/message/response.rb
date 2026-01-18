# frozen_string_literal: true

require "command_tower/schema/entities/inbox/message_entity"

module CommandTower
  module Schema
    module Inbox
      module Messages
        module Message
          class Response < JsonSchematize::Generator
            # Response is the Entities::Inbox::MessageEntity schema
            # We'll use it directly in the controller
          end
        end
      end
    end
  end
end
