# frozen_string_literal: true

module CommandTower
  module InboxService
    module Blast
      class Delete < CommandTower::ServiceBase
        on_argument_validation :fail_early

        validate :id, is_a: Integer, required: true

        def call
          message_blast = ::MessageBlast.where(id:).first

          if message_blast.nil?
            inline_argument_failure!(errors: { id: "MessageBlast ID not found" })
          end

          message_blast.destroy
        end
      end
    end
  end
end
