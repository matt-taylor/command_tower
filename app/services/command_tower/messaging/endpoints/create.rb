# frozen_string_literal: true

module CommandTower
  module Messaging
    module Endpoints
      # Local persist only. Never contacts providers (Pushover Transport included).
      class Create
        def self.call(owner_user_id:, channel_key:, address: nil, credentials: nil)
          new(owner_user_id:, channel_key:, address:, credentials:).call
        end

        def initialize(owner_user_id:, channel_key:, address:, credentials:)
          @owner_user_id = owner_user_id
          @channel_key = channel_key.to_s
          @address = address
          @credentials = credentials
        end

        def call
          ChannelGate.assert_endpoint_backed!(@channel_key)

          if Endpoint.typed_credentials_channel?(@channel_key)
            create_typed_credentials
          else
            create_address_backed
          end
        end

        private

        def create_typed_credentials
          assert_pushover_credentials_contract!

          validated = Validators.validate_pushover_credentials!(@credentials)
          attrs = Persistence.build_pushover_parent_attrs(validated:)
          fingerprint = attrs.fetch(:address_fingerprint)

          existing = Persistence.find_active_by_fingerprint(
            owner_user_id: @owner_user_id,
            channel_key: @channel_key,
            fingerprint:,
          )
          if existing
            return resolve_idempotent_pushover(existing, validated)
          end

          assert_no_other_single_active!

          insert_pushover(attrs, fingerprint, validated)
        end

        def create_address_backed
          assert_address_contract!

          validated = Validators.validate!(channel_key: @channel_key, address: @address)
          attrs = Persistence.build_encrypted_attrs(
            normalized_address: validated.normalized_address,
            masked_display_value: validated.masked_display_value,
          )
          fingerprint = attrs.fetch(:address_fingerprint)

          existing = Persistence.find_active_by_fingerprint(
            owner_user_id: @owner_user_id,
            channel_key: @channel_key,
            fingerprint:,
          )
          return SafeView.from_record(existing) if existing

          assert_no_other_single_active!

          insert_address_backed(attrs, fingerprint)
        end

        def assert_pushover_credentials_contract!
          if @address.present?
            raise ValidationError, "pushover create requires credentials: and must not pass address:"
          end
          if @credentials.nil?
            raise ValidationError, "pushover create requires credentials: with user_key and application_token"
          end
        end

        def assert_address_contract!
          if @credentials.present?
            raise ValidationError, "channel #{@channel_key.inspect} does not accept credentials:"
          end
          if @address.nil?
            raise ValidationError, "address must be present"
          end
        end

        def assert_no_other_single_active!
          return unless Endpoint.single_active_channel?(@channel_key)

          other = Endpoint.active.for_owner(@owner_user_id).for_channel(@channel_key).first
          return if other.nil?

          if Endpoint.typed_credentials_channel?(@channel_key)
            raise ConflictError,
                  "an active endpoint already exists for this owner and channel with different credentials; use replace"
          end

          raise ConflictError,
                "an active endpoint already exists for this owner and channel; use replace"
        end

        def resolve_idempotent_pushover(existing, validated)
          stored = SecretReader.read_pushover_credentials!(
            owner_user_id: @owner_user_id,
            endpoint_id: existing.id,
          )
          same_pair =
            stored.fetch(:user_key) == validated.normalized_user_key &&
            stored.fetch(:application_token) == validated.normalized_application_token

          return SafeView.from_record(existing) if same_pair

          raise ConflictError,
                "an active endpoint already exists for this owner and channel with different credentials; use replace"
        end

        def insert_pushover(attrs, fingerprint, validated)
          Endpoint.transaction do
            record = Endpoint.new(
              user_id: @owner_user_id,
              channel_key: @channel_key,
              lifecycle_state: "active",
              verification_state: "unverified",
              **attrs,
            )
            record.derive_uniqueness_columns!
            record.save!
            Persistence.create_pushover_credential!(endpoint: record, validated:)
            SafeView.from_record(record.reload)
          end
        rescue ActiveRecord::RecordNotUnique => e
          handle_unique_conflict(e, fingerprint)
        end

        def insert_address_backed(attrs, fingerprint)
          record = Endpoint.new(
            user_id: @owner_user_id,
            channel_key: @channel_key,
            lifecycle_state: "active",
            verification_state: "unverified",
            **attrs,
          )
          record.derive_uniqueness_columns!
          record.save!
          SafeView.from_record(record)
        rescue ActiveRecord::RecordNotUnique => e
          handle_unique_conflict(e, fingerprint)
        end

        def handle_unique_conflict(error, fingerprint)
          message = error.message.to_s
          if message.include?("active_fingerprint")
            existing = Persistence.find_active_by_fingerprint(
              owner_user_id: @owner_user_id,
              channel_key: @channel_key,
              fingerprint:,
            )
            if existing
              return SafeView.from_record(existing) unless Endpoint.typed_credentials_channel?(@channel_key)

              validated = Validators.validate_pushover_credentials!(@credentials)
              return resolve_idempotent_pushover(existing, validated)
            end
          end

          if message.include?("single_active_slot")
            raise ConflictError,
                  "an active endpoint already exists for this owner and channel; use replace"
          end

          raise ConflictError, "endpoint uniqueness conflict"
        end
      end
    end
  end
end
