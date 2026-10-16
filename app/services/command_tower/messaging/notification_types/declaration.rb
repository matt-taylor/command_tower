# frozen_string_literal: true

module CommandTower
  module Messaging
    module NotificationTypes
      Declaration = Data.define(
        :key,
        :allowed_channels,
        :default_channels,
        :inbox_available,
        :user_configurable,
        :mandatory,
        :default_preference_state,
        :label,
        :category_key,
        :category_label,
        :category_order,
        :type_order,
        :settings_visible,
        :description,
        :priority,
        :retention,
        :delivery_status_visible,
        :host_ownership,
        :inbox_document_composer,
        :badge_eligible,
        :urgency,
        :sound,
        :deep_link_required,
        :destination_locks,
      ) do
        def self.build(
          key:,
          allowed_channels:,
          default_channels:,
          inbox_available:,
          user_configurable:,
          mandatory:,
          default_preference_state:,
          label:,
          category_key:,
          category_label:,
          category_order:,
          type_order:,
          settings_visible: true,
          description: nil,
          priority: nil,
          retention: nil,
          delivery_status_visible: nil,
          host_ownership: nil,
          inbox_document_composer: nil,
          badge_eligible: false,
          urgency: nil,
          sound: nil,
          deep_link_required: false,
          destination_locks: {}
        )
          new(
            key: key.nil? ? nil : key.to_s,
            allowed_channels: freeze_channel_list(allowed_channels),
            default_channels: freeze_channel_list(default_channels),
            inbox_available: !!inbox_available,
            user_configurable: !!user_configurable,
            mandatory: !!mandatory,
            default_preference_state: freeze_preference_state(default_preference_state),
            label: label.nil? ? nil : label.to_s,
            category_key: category_key.nil? ? nil : category_key.to_s,
            category_label: category_label.nil? ? nil : category_label.to_s,
            category_order:,
            type_order:,
            settings_visible: !!settings_visible,
            description:,
            priority:,
            retention:,
            delivery_status_visible:,
            host_ownership:,
            # Rich Messaging Slice 2.5 revision — String class name of a
            # pure-Ruby Inbox document composer (`.call(communication:) ->
            # InboxDocument`), lazily `.constantize`d by
            # `InboxDocumentRenderer` at render time, never at registration
            # time (mirrors the existing RBAC `Entity#controller` deferred
            # class-string convention — decouples host `to_prepare`
            # registration order from composer class-load order). `nil`
            # means this type intentionally has no custom Inbox document and
            # renders via `InboxDocumentRenderer#build_generic`. See
            # artifacts/visual-improvements/rich-messaging/authority/RICH_MESSAGING_RUBY_INBOX_DEFINITION_DISCOVERY.md.
            inbox_document_composer: inbox_document_composer.nil? ? nil : inbox_document_composer.to_s,
            # Notification Product Behavior (NPB-1). All default to today's behavior.
            # `badge_eligible`: unread inbox items of this type count toward the app-icon badge.
            # `urgency` / `sound`: `{ default:, allowed: [ids] | "all" }`; nil is fixed
            # "normal" / "default". Invalid input is kept so DeclarationValidator reports it.
            badge_eligible: !!badge_eligible,
            urgency: PermittedChoice.from(urgency, fallback_default: "normal"),
            sound: PermittedChoice.from(sound, fallback_default: "default"),
            # NPB-5. Push-capable types that are not inbox-backed must set this
            # so Produce can reject a missing metadata deep_link.
            deep_link_required: !!deep_link_required,
            destination_locks: freeze_destination_locks(destination_locks),
          ).freeze
        end

        def self.freeze_destination_locks(locks)
          return {}.freeze if locks.nil? || locks.empty?

          unless locks.respond_to?(:to_h)
            return {}.freeze
          end

          locks.to_h.transform_keys(&:to_s).transform_values(&:to_s).freeze
        end
        private_class_method :freeze_destination_locks

        def self.freeze_channel_list(channels)
          return nil if channels.nil?

          Array(channels).map { |channel| channel.to_s }.freeze
        end
        private_class_method :freeze_channel_list

        def self.freeze_preference_state(state)
          return nil if state.nil?

          hash = state.to_h.transform_keys(&:to_s)
          channels = hash["channels"]
          frozen_channels =
            if channels.nil?
              nil
            else
              channels.to_h.transform_keys(&:to_s).transform_values { |value| !!value }.freeze
            end

          {
            "channels" => frozen_channels,
            "inbox" => hash.key?("inbox") ? !!hash["inbox"] : nil,
          }.freeze
        end
        private_class_method :freeze_preference_state
      end
    end
  end
end
