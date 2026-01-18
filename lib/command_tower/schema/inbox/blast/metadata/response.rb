# frozen_string_literal: true

require "command_tower/schema/shared/inbox/message_blast_metadata"

module CommandTower
  module Schema
    module Inbox
      module Blast
        module Metadata
          class Response < JsonSchematize::Generator
            # Response is the Shared::Inbox::MessageBlastMetadata schema
            # We'll use it directly in the controller
          end
        end
      end
    end
  end
end
