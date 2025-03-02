# frozen_string_literal: true

module ApiEngineBase
  module InboxService
    module Blast
      class Delete < ApiEngineBase::ServiceBase
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
