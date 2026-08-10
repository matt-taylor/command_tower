# frozen_string_literal: true

module CommandTower
  module Messaging
    module Endpoints
      # Local retire+insert only. New row is always unverified; never contacts providers.
      class Replace
        def self.call(owner_user_id:, channel_key: nil, endpoint_id: nil, address: nil, credentials: nil)
          new(owner_user_id:, channel_key:, endpoint_id:, address:, credentials:).call
        end

        def initialize(owner_user_id:, channel_key:, endpoint_id:, address:, credentials:)
          @owner_user_id = owner_user_id
          @address = address
          @credentials = credentials
          @channel_key = channel_key&.to_s
          @endpoint_id = endpoint_id
        end

        def call
          if @endpoint_id
            replace_by_endpoint_id
          elsif @channel_key
            replace_single_active_channel
          else
            raise ValidationError, "replace requires endpoint_id (push) or channel_key (pushover)"
          end
        end

        private

        def replace_by_endpoint_id
          attempts = 0
          begin
            attempts += 1
            Endpoint.transaction do
              target = Endpoint.for_owner(@owner_user_id).lock.find_by(id: @endpoint_id)
              raise NotFoundError, "endpoint not found" if target.nil?

              ChannelGate.assert_record_supported!(target)
              channel_key = target.channel_key

              if Endpoint.typed_credentials_channel?(channel_key)
                raise ValidationError,
                      "pushover replace requires channel_key: (single-active), not endpoint_id:"
              end

              assert_address_only_contract!
              validated = Validators.validate!(channel_key:, address: @address)
              attrs = Persistence.build_encrypted_attrs(
                normalized_address: validated.normalized_address,
                masked_display_value: validated.masked_display_value,
              )

              retire!(target)
              insert_address_replacement(channel_key:, attrs:)
            end
          rescue ActiveRecord::RecordNotUnique
            raise ConflictError, "concurrent endpoint replace conflict" if attempts >= Persistence::MAX_RETRIES

            retry
          end
        end

        def replace_single_active_channel
          ChannelGate.assert_endpoint_backed!(@channel_key)
          unless Endpoint.single_active_channel?(@channel_key)
            raise ValidationError,
                  "channel #{@channel_key.inspect} is multi-active; replace requires endpoint_id"
          end

          if Endpoint.typed_credentials_channel?(@channel_key)
            replace_pushover
          else
            replace_address_single_active
          end
        end

        def replace_pushover
          assert_pushover_credentials_contract!
          validated = Validators.validate_pushover_credentials!(@credentials)
          attrs = Persistence.build_pushover_parent_attrs(validated:)

          attempts = 0
          begin
            attempts += 1
            Endpoint.transaction do
              retire_actives!(@channel_key)
              insert_pushover_replacement(attrs:, validated:)
            end
          rescue ActiveRecord::RecordNotUnique
            raise ConflictError, "concurrent endpoint replace conflict" if attempts >= Persistence::MAX_RETRIES

            retry
          end
        end

        def replace_address_single_active
          assert_address_only_contract!
          validated = Validators.validate!(channel_key: @channel_key, address: @address)
          attrs = Persistence.build_encrypted_attrs(
            normalized_address: validated.normalized_address,
            masked_display_value: validated.masked_display_value,
          )

          attempts = 0
          begin
            attempts += 1
            Endpoint.transaction do
              retire_actives!(@channel_key)
              insert_address_replacement(channel_key: @channel_key, attrs:)
            end
          rescue ActiveRecord::RecordNotUnique
            raise ConflictError, "concurrent endpoint replace conflict" if attempts >= Persistence::MAX_RETRIES

            retry
          end
        end

        def assert_pushover_credentials_contract!
          if @address.present?
            raise ValidationError, "pushover replace requires credentials: and must not pass address:"
          end
          if @credentials.nil?
            raise ValidationError, "pushover replace requires credentials: with user_key and application_token"
          end
        end

        def assert_address_only_contract!
          if @credentials.present?
            raise ValidationError, "channel does not accept credentials:"
          end
          if @address.nil?
            raise ValidationError, "address must be present"
          end
        end

        def retire!(target)
          return if target.terminal?

          Lifecycle.apply!(target, to: "retired")
          target.save!
        end

        def retire_actives!(channel_key)
          Endpoint.active.for_owner(@owner_user_id).for_channel(channel_key).lock.to_a.each do |prior|
            Lifecycle.apply!(prior, to: "retired")
            prior.save!
          end
        end

        def insert_address_replacement(channel_key:, attrs:)
          record = Endpoint.new(
            user_id: @owner_user_id,
            channel_key:,
            lifecycle_state: "active",
            verification_state: "unverified",
            **attrs,
          )
          record.derive_uniqueness_columns!
          record.save!
          SafeView.from_record(record)
        end

        def insert_pushover_replacement(attrs:, validated:)
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
      end
    end
  end
end
