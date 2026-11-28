# frozen_string_literal: true

require "class_composer"

module CommandTower
  module Configuration
    module Messaging
      class Inbox < ::CommandTower::Configuration::Base
        include ClassComposer::Generator

        add_composer :restore_archived_thread_on_new_message,
                     desc: "When true, a genuinely new inbox item that carries a conversation_key restores the " \
                           "recipient's archived, non-deleted, non-resolved items in the same conversation " \
                           "(after commit). Idempotent replays never restore. Restoring brings back archived " \
                           "unread members, so one new message can raise the unread count by more than one. " \
                           "Default false (archived threads stay archived).",
                     allowed: [TrueClass, FalseClass],
                     default: false
      end
    end
  end
end
