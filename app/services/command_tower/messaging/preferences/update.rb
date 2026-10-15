# frozen_string_literal: true

module CommandTower
  module Messaging
    module Preferences
      class Update
        def self.call(...)
          new(...).call
        end

        def initialize(
          recipient_id:,
          notification_type_key:,
          preference_state:,
          platform_enabled_channels: []
        )
          @recipient_id = recipient_id
          @notification_type_key = notification_type_key.to_s
          @preference_state = preference_state
          @platform_enabled_channels = Array(platform_enabled_channels).map(&:to_s).freeze
        end

        def call
          declaration = lookup_declaration!
          validate_settings_visible!(declaration)
          validate_writable!(declaration)

          submitted_destinations = nil

          if reset_request?
            persist_reset!
          else
            patch_hash = normalized_preference_hash
            submitted_destinations = extract_submitted_destinations(patch_hash)
            candidate = build_candidate_state!(declaration, patch_hash:)
            sparse = sparsify(declaration, candidate)
            persist_sparse!(sparse)
          end

          evaluation = Resolve.call(
            notification_type_key: @notification_type_key,
            recipient_id: @recipient_id,
            platform_enabled_channels: @platform_enabled_channels,
          )

          build_notification_result(
            declaration,
            evaluation,
            recipient_ready_channel_keys,
            submitted_destinations:,
          )
        end

        private

        def recipient_ready_channel_keys
          RecipientReadiness.for_recipient(
            recipient_id: @recipient_id,
            platform_enabled_channels: @platform_enabled_channels,
          ).recipient_ready_channel_keys
        rescue RecipientReadiness::RecipientNotFoundError
          []
        end

        def lookup_declaration!
          NotificationTypes.lookup(@notification_type_key)
        rescue NotificationTypes::NotFoundError
          raise UnknownTypeError, "notification type not registered: #{@notification_type_key}"
        end

        def validate_settings_visible!(declaration)
          return if declaration.settings_visible

          raise NotSettingsVisibleError,
                "notification type is not settings-visible: #{declaration.key}"
        end

        def validate_writable!(declaration)
          return if declaration.user_configurable

          raise InvalidPreferenceWriteError,
                "notification type is not user-configurable: #{declaration.key}"
        end

        def reset_request?
          return true if @preference_state.nil?

          @preference_state.respond_to?(:to_h) && @preference_state.to_h.empty?
        end

        def normalized_preference_hash
          unless @preference_state.respond_to?(:to_h)
            raise InvalidPreferenceStateError, "preference_state must be a hash-like object"
          end

          @preference_state.to_h.transform_keys(&:to_s)
        end

        def extract_submitted_destinations(hash)
          submitted = {}
          submitted["inbox"] = hash["inbox"] if hash.key?("inbox")
          if hash.key?("channels") && hash["channels"].respond_to?(:to_h)
            hash["channels"].to_h.each do |raw_key, raw_value|
              submitted[raw_key.to_s] = raw_value
            end
          end
          submitted.freeze
        end

        def build_candidate_state!(declaration, patch_hash: nil)
          hash = patch_hash || normalized_preference_hash
          unknown_keys = hash.keys - %w[channels inbox urgency sound]
          if unknown_keys.any?
            raise InvalidPreferenceWriteError,
                  "unsupported preference keys: #{unknown_keys.join(', ')}"
          end

          patch = build_patch_partial!(declaration, hash)
          merged = patch.merge_over(stored_member_state)
          DestinationLocks.apply(declaration:, state: merged)
        end

        def stored_member_state
          Store.find(
            recipient_id: @recipient_id,
            notification_type_key: @notification_type_key,
          ) || empty_stored_member_state
        end

        def empty_stored_member_state
          PreferenceState.new(channels: {}.freeze, inbox: nil, urgency: nil, sound: nil).freeze
        end

        def build_patch_partial!(declaration, hash)
          channels =
            if hash.key?("channels")
              parse_channels!(declaration, hash["channels"])
            else
              {}.freeze
            end

          PreferenceState.new(
            channels: channels.freeze,
            inbox: parse_inbox!(declaration, hash),
            urgency: parse_choice!(declaration, hash, "urgency"),
            sound: parse_choice!(declaration, hash, "sound"),
          ).freeze
        end

        def parse_channels!(declaration, channels_raw)
          return {}.freeze if channels_raw.nil?

          unless channels_raw.respond_to?(:to_h)
            raise InvalidPreferenceStateError, "preference_state channels must be a hash-like object"
          end

          channels = {}
          channels_raw.to_h.each do |raw_key, raw_value|
            key = raw_key.to_s
            unless declaration.allowed_channels.include?(key)
              raise InvalidPreferenceWriteError,
                    "preference channels outside allowed set: #{key}"
            end
            unless [true, false].include?(raw_value)
              raise InvalidPreferenceStateError,
                    "preference channel values must be boolean: #{key}"
            end

            channels[key] = raw_value
          end
          channels
        end

        def parse_inbox!(declaration, hash)
          return nil unless hash.key?("inbox")

          unless [true, false].include?(hash["inbox"])
            raise InvalidPreferenceStateError, "preference inbox must be a boolean"
          end

          unless declaration.inbox_available
            raise InvalidPreferenceWriteError,
                  "inbox preference is not available for notification type: #{declaration.key}"
          end

          hash["inbox"]
        end

        def parse_choice!(declaration, hash, field)
          return nil unless hash.key?(field)

          EffectiveChoice.validate_write!(declaration:, field: field.to_sym, value: hash[field])
          hash[field].strip
        end

        def sparsify(declaration, candidate)
          defaults = PreferenceState.from_declaration_default(declaration.default_preference_state)
          sparse_channels = {}

          candidate.channels.each do |channel, enabled|
            default_enabled = defaults.channel_enabled?(channel, default: true)
            sparse_channels[channel] = enabled unless enabled == default_enabled
          end

          sparse_inbox =
            if candidate.inbox.nil?
              nil
            elsif candidate.inbox == defaults.inbox
              nil
            else
              candidate.inbox
            end

          sparse_urgency = sparse_choice(candidate.urgency, declaration.urgency.default)
          sparse_sound = sparse_choice(candidate.sound, declaration.sound.default)
          return nil if sparse_channels.empty? && sparse_inbox.nil? && sparse_urgency.nil? && sparse_sound.nil?

          PreferenceState.new(
            channels: sparse_channels.freeze,
            inbox: sparse_inbox,
            urgency: sparse_urgency,
            sound: sparse_sound,
          ).freeze
        end

        def sparse_choice(value, default)
          return nil if value.nil? || value == default

          value
        end

        def persist_reset!
          current = Store.find(
            recipient_id: @recipient_id,
            notification_type_key: @notification_type_key,
          )
          return if current.nil?

          ActiveRecord::Base.transaction do
            Store.delete!(
              recipient_id: @recipient_id,
              notification_type_key: @notification_type_key,
            )
          end
        end

        def persist_sparse!(sparse)
          current = Store.find(
            recipient_id: @recipient_id,
            notification_type_key: @notification_type_key,
          )

          if sparse.nil?
            return if current.nil?

            ActiveRecord::Base.transaction do
              Store.delete!(
                recipient_id: @recipient_id,
                notification_type_key: @notification_type_key,
              )
            end
            return
          end

          return if same_stored_state?(current, sparse)

          ActiveRecord::Base.transaction do
            Store.upsert!(
              recipient_id: @recipient_id,
              notification_type_key: @notification_type_key,
              preference_state: sparse.to_raw_hash,
            )
          end
        end

        def same_stored_state?(current, sparse)
          return false if current.nil?

          current.to_raw_hash == sparse.to_raw_hash
        end

        def build_notification_result(declaration, evaluation, recipient_ready_keys, submitted_destinations: nil)
          available =
            declaration.allowed_channels & @platform_enabled_channels & recipient_ready_keys

          NotificationAssembly.build(
            declaration:,
            evaluation:,
            available_channels: available,
            recipient_id: @recipient_id,
            submitted_destinations:,
          )
        end
      end
    end
  end
end
