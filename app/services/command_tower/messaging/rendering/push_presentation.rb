# frozen_string_literal: true

module CommandTower
  module Messaging
    module Rendering
      # Resolves how a push should present itself, in provider-neutral terms: the member's
      # effective urgency, the sound asset (nil for System Default), the conversation
      # thread, and, for a badge-eligible type, the recipient's current badge-eligible
      # unread count. Reads the member's stored preference once. Reads the unread count
      # once, through Messaging::Inbox, only when the declaration is badge-eligible.
      # The provider adapter maps the result to its own fields. Never raises for an
      # unregistered type or an unreadable preference: it returns defaults and records
      # a fallback diagnostic instead. An eligible type keeps its badge on that
      # preference fallback. Any other error, including a count failure, surfaces.
      class PushPresentation
        Result = Data.define(:urgency, :sound, :thread_id, :badge)

        DEFAULT_URGENCY = "normal"

        def self.call(communication:, channel_delivery: nil)
          new(communication:, channel_delivery:).call
        end

        def initialize(communication:, channel_delivery: nil)
          @communication = communication
          @channel_delivery = channel_delivery
        end

        def call
          declaration = NotificationTypes.lookup(@communication.notification_type_key)
          badge = badge_count(declaration)
          blocks = Preferences::EffectiveChoice.call(declaration:, stored: stored_state(declaration))

          build(
            urgency: blocks.dig(:urgency, :effective),
            sound: sound_asset(blocks.dig(:sound, :effective)),
            badge:,
          )
        rescue NotificationTypes::NotFoundError
          fall_back(reason_code: "type_unregistered")
        rescue Preferences::StoreError, Preferences::InvalidPreferenceStateError
          fall_back(reason_code: "preference_unreadable", badge:)
        end

        private

        # A type the member cannot configure ignores any stored override, as the
        # channel evaluation does.
        def stored_state(declaration)
          return nil unless declaration.user_configurable

          Preferences::Store.find(
            recipient_id: @communication.user_id,
            notification_type_key: declaration.key,
          )
        end

        def sound_asset(sound_id)
          SoundCatalog.fetch(sound_id)&.fetch(:asset)
        end

        # Nil for a type that is not badge-eligible, so the adapter omits Expo `badge`.
        # The count is NPB-4's absolute eligible unread total, including 0.
        def badge_count(declaration)
          return nil unless declaration.badge_eligible

          Inbox.unread_count(recipient_id: @communication.user_id).badge_count
        end

        def build(urgency:, sound:, badge: nil)
          Result.new(
            urgency:,
            sound:,
            thread_id: @communication.conversation_key.presence,
            badge:,
          ).freeze
        end

        def fall_back(reason_code:, badge: nil)
          Execution::OperationLogger.push_presentation_fallback(
            communication: @communication,
            reason_code:,
            channel_delivery: @channel_delivery,
          )
          build(urgency: DEFAULT_URGENCY, sound: nil, badge:)
        end
      end
    end
  end
end
