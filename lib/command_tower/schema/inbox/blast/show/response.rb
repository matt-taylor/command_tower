# frozen_string_literal: true

require "command_tower/schema/entities/inbox/message_blast_entity"

module CommandTower
  module Schema
    module Inbox
      module Blast
        module Show
          class Response < JsonSchematize::Generator
            # Response is the Entities::Inbox::MessageBlastEntity schema
            # We'll use it directly in the controller
          end
        end
      end
    end
  end
end
