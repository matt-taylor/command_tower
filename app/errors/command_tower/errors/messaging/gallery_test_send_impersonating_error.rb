# frozen_string_literal: true

module CommandTower
  module Errors
    module Messaging
      # The gallery test send goes to the real actor's own address, so it is refused while
      # impersonating or whenever the actor is not the effective user.
      class GalleryTestSendImpersonatingError < CommandTower::Errors::ApplicationError
        def code
          "gallery_test_send_impersonating"
        end

        def message
          "The gallery test send is unavailable while impersonating a user."
        end

        def log_level
          :warn
        end
      end
    end
  end
end
