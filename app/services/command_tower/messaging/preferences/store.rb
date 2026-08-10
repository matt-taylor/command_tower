# frozen_string_literal: true

module CommandTower
  module Messaging
    module Preferences
      class Store
        def self.find(recipient_id:, notification_type_key:)
          new.find(recipient_id:, notification_type_key:)
        end

        def self.upsert!(recipient_id:, notification_type_key:, preference_state:)
          new.upsert!(recipient_id:, notification_type_key:, preference_state:)
        end

        def self.delete!(recipient_id:, notification_type_key:)
          new.delete!(recipient_id:, notification_type_key:)
        end

        def find(recipient_id:, notification_type_key:)
          record = Messaging::NotificationPreference.find_for(
            recipient_id:,
            notification_type_key:,
          )
          return nil if record.nil?

          PreferenceState.normalize(record.state)
        rescue ActiveRecord::ActiveRecordError => error
          raise StoreError, "failed to load notification preference: #{error.message}"
        rescue InvalidPreferenceStateError
          raise
        end

        def upsert!(recipient_id:, notification_type_key:, preference_state:)
          key = notification_type_key.to_s
          declaration = lookup_declaration!(key)
          validate_writable!(declaration)

          normalized = PreferenceState.normalize(preference_state)
          if normalized.nil?
            raise InvalidPreferenceWriteError, "preference_state must be present"
          end

          validate_channels!(declaration, normalized)
          validate_inbox!(declaration, normalized)

          persist!(recipient_id:, notification_type_key: key, state: normalized.to_raw_hash)
          normalized
        rescue ActiveRecord::ActiveRecordError => error
          raise StoreError, "failed to persist notification preference: #{error.message}"
        end

        def delete!(recipient_id:, notification_type_key:)
          key = notification_type_key.to_s
          record = Messaging::NotificationPreference.find_for(
            recipient_id:,
            notification_type_key: key,
          )
          return if record.nil?

          record.destroy!
          nil
        rescue ActiveRecord::ActiveRecordError => error
          raise StoreError, "failed to delete notification preference: #{error.message}"
        end

        private

        def lookup_declaration!(key)
          NotificationTypes.lookup(key)
        rescue NotificationTypes::NotFoundError
          raise UnknownTypeError, "notification type not registered: #{key}"
        end

        def validate_writable!(declaration)
          return if declaration.user_configurable

          raise InvalidPreferenceWriteError,
                "notification type is not user-configurable: #{declaration.key}"
        end

        def validate_channels!(declaration, normalized)
          extras = normalized.channels.keys - declaration.allowed_channels
          return if extras.empty?

          raise InvalidPreferenceWriteError,
                "preference channels outside allowed set: #{extras.join(', ')}"
        end

        def validate_inbox!(declaration, normalized)
          return if normalized.inbox.nil?
          return if declaration.inbox_available

          raise InvalidPreferenceWriteError,
                "inbox preference is not available for notification type: #{declaration.key}"
        end

        def persist!(recipient_id:, notification_type_key:, state:)
          record = Messaging::NotificationPreference.find_for(
            recipient_id:,
            notification_type_key:,
          )

          if record.nil?
            begin
              Messaging::NotificationPreference.create!(
                user_id: recipient_id,
                notification_type_key:,
                state:,
              )
            rescue ActiveRecord::RecordNotUnique
              record = Messaging::NotificationPreference.find_for(
                recipient_id:,
                notification_type_key:,
              )
              raise StoreError, "failed to persist notification preference" if record.nil?

              record.update!(state:)
            end
          else
            record.update!(state:)
          end
        end
      end
    end
  end
end
