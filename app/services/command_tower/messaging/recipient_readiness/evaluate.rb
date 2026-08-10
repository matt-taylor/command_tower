# frozen_string_literal: true

module CommandTower
  module Messaging
    module RecipientReadiness
      class Evaluate
        def self.for_channel(recipient_id:, channel_key:, platform_enabled_channels: [])
          new(
            recipient_id:,
            platform_enabled_channels:,
          ).for_channel(channel_key)
        end

        def self.for_recipient(recipient_id:, platform_enabled_channels: [])
          new(
            recipient_id:,
            platform_enabled_channels:,
          ).for_recipient
        end

        def initialize(recipient_id:, platform_enabled_channels: [])
          @recipient_id = recipient_id
          @platform_enabled_channels = Array(platform_enabled_channels).map(&:to_s).freeze
          @evaluated_at = Time.current
        end

        def for_channel(channel_key)
          key = channel_key.to_s
          definition = Channels.fetch(key)
          raise UnknownChannelError, "unknown channel: #{key.inspect}" if definition.nil?

          user = load_user!
          result = evaluate_definition(definition, user)
          log_evaluation(result)
          result
        end

        def for_recipient
          user = load_user!
          channels = {}

          Channels.definitions.each do |definition|
            channels[definition.key] = evaluate_definition(definition, user)
          end

          result = RecipientResult.build(
            recipient_id: @recipient_id,
            channels:,
            evaluated_at: @evaluated_at,
          )
          channels.each_value { |channel_result| log_evaluation(channel_result) }
          result
        end

        private

        def load_user!
          user = ::User.find_by(id: @recipient_id)
          raise RecipientNotFoundError, "recipient not found: #{@recipient_id.inspect}" if user.nil?

          user
        end

        def evaluate_definition(definition, user)
          key = definition.key
          platform_enabled = platform_enabled_for?(definition)
          platform_configured = platform_configured_for?(definition)

          recipient =
            if definition.inbox?
              evaluate_inbox(user)
            elsif definition.identity_backed
              evaluate_identity(definition, user)
            elsif definition.supports_endpoint_records
              evaluate_endpoints(key)
            else
              empty_recipient_result
            end

          reason_codes = []
          reason_codes << ReasonCodes::PLATFORM_DISABLED unless platform_enabled
          reason_codes << ReasonCodes::PLATFORM_UNCONFIGURED unless platform_configured
          reason_codes.concat(recipient[:reason_codes])

          recipient_ready = recipient[:recipient_ready]
          ready = platform_enabled && platform_configured && recipient_ready

          ChannelResult.build(
            channel_key: key,
            ready:,
            platform_enabled:,
            platform_configured:,
            recipient_ready:,
            status: ready ? "ready" : "unavailable",
            reason_codes: reason_codes.uniq,
            endpoint_count: recipient[:endpoint_count],
            eligible_endpoint_count: recipient[:eligible_endpoint_count],
            eligible_endpoint_ids: recipient[:eligible_endpoint_ids],
            resolved_endpoint_id: recipient[:resolved_endpoint_id],
            verification_required: recipient[:verification_required],
            evaluated_at: @evaluated_at,
          )
        end

        def platform_enabled_for?(definition)
          return true if definition.inbox?

          @platform_enabled_channels.include?(definition.key)
        end

        def platform_configured_for?(definition)
          return true if definition.inbox?

          CommandTower::Messaging::ChannelDetectors.configured?(definition.key)
        end

        def evaluate_inbox(_user)
          empty_recipient_result.merge(recipient_ready: true)
        end

        def evaluate_identity(definition, user)
          facts = IdentityFacts.for_user(user)

          case definition.key
          when "email"
            evaluate_email_identity(facts)
          when "sms"
            evaluate_phone_identity(facts)
          else
            identity_result(false, ReasonCodes::IDENTITY_UNAVAILABLE, verification_required: true)
          end
        end

        def evaluate_email_identity(facts)
          unless facts.email_supported
            return identity_unavailable_result
          end
          unless facts.email_present
            return identity_result(false, ReasonCodes::IDENTITY_MISSING, verification_required: true)
          end
          unless facts.email_validated
            return identity_result(false, ReasonCodes::IDENTITY_UNVERIFIED, verification_required: true)
          end

          identity_result(true, nil, verification_required: false)
        end

        def evaluate_phone_identity(facts)
          unless facts.phone_supported
            return identity_unavailable_result
          end
          unless facts.phone_present
            return identity_result(false, ReasonCodes::IDENTITY_MISSING, verification_required: true)
          end
          unless facts.phone_number_validated
            return identity_result(false, ReasonCodes::IDENTITY_UNVERIFIED, verification_required: true)
          end

          identity_result(true, nil, verification_required: false)
        end

        def identity_unavailable_result
          identity_result(false, ReasonCodes::IDENTITY_UNAVAILABLE, verification_required: true)
        end

        def identity_result(ready, reason, verification_required:)
          empty_recipient_result.merge(
            recipient_ready: ready,
            reason_codes: reason ? [reason] : [],
            verification_required:,
          )
        end

        def empty_recipient_result
          {
            recipient_ready: false,
            reason_codes: [],
            endpoint_count: 0,
            eligible_endpoint_count: 0,
            eligible_endpoint_ids: [],
            resolved_endpoint_id: nil,
            verification_required: false,
          }
        end

        def evaluate_endpoints(channel_key)
          views = Endpoints.list(owner_user_id: @recipient_id, channel_key:)
          endpoint_count = views.size
          eligible = views.select { |view| eligible_endpoint?(view, channel_key) }
          eligible_ids = eligible.map(&:id)

          if endpoint_count.zero?
            return endpoint_result(
              false,
              ReasonCodes::ENDPOINT_MISSING,
              endpoint_count:,
              eligible_ids: [],
              verification_required: true,
            )
          end

          if eligible_ids.size == 1
            return endpoint_result(
              true,
              nil,
              endpoint_count:,
              eligible_ids:,
              resolved_endpoint_id: eligible_ids.first,
              verification_required: false,
            )
          end

          if eligible_ids.size > 1
            # Single-active / typed-credential channels must resolve exactly one endpoint.
            # Multi-device channels (e.g. push) remain recipient_ready without a single resolved id.
            if Endpoint.single_active_channel?(channel_key) ||
                Endpoint.typed_credentials_channel?(channel_key)
              return endpoint_result(
                false,
                ReasonCodes::ENDPOINT_INVALID,
                endpoint_count:,
                eligible_ids:,
                verification_required: false,
              )
            end

            return endpoint_result(
              true,
              nil,
              endpoint_count:,
              eligible_ids:,
              verification_required: false,
            )
          end

          reason = endpoint_not_ready_reason(views, channel_key)
          endpoint_result(
            false,
            reason,
            endpoint_count:,
            eligible_ids: [],
            verification_required: reason != ReasonCodes::ENDPOINT_INVALID &&
              reason != ReasonCodes::CREDENTIALS_MISSING,
          )
        end

        def eligible_endpoint?(view, channel_key)
          return false unless view.lifecycle_state == "active"
          return false unless view.verification_state == "verified"

          if Endpoint.typed_credentials_channel?(channel_key)
            return false unless view.credentials_configured
          end

          true
        end

        def endpoint_not_ready_reason(views, channel_key)
          active = views.select { |view| view.lifecycle_state == "active" }
          if active.empty?
            return ReasonCodes::ENDPOINT_INVALID if views.all? { |view|
              %w[revoked invalid retired].include?(view.lifecycle_state)
            }

            return ReasonCodes::ENDPOINT_INACTIVE
          end

          if active.any? { |view| view.verification_state != "verified" }
            return ReasonCodes::ENDPOINT_UNVERIFIED
          end

          if Endpoint.typed_credentials_channel?(channel_key) &&
              active.any? { |view|
                view.verification_state == "verified" && !view.credentials_configured
              }
            return ReasonCodes::CREDENTIALS_MISSING
          end

          ReasonCodes::ENDPOINT_INVALID
        end

        def endpoint_result(
          ready,
          reason,
          endpoint_count:,
          eligible_ids:,
          verification_required:,
          resolved_endpoint_id: nil
        )
          {
            recipient_ready: ready,
            reason_codes: reason ? [reason] : [],
            endpoint_count:,
            eligible_endpoint_count: eligible_ids.size,
            eligible_endpoint_ids: eligible_ids,
            resolved_endpoint_id: ready ? resolved_endpoint_id : nil,
            verification_required:,
          }
        end

        def log_evaluation(result)
          Contract::Observability::StructuredLogger.info(
            event: "messaging.recipient_readiness.evaluated",
            recipient_id: @recipient_id,
            channel_key: result.channel_key,
            ready: result.ready,
            platform_enabled: result.platform_enabled,
            platform_configured: result.platform_configured,
            recipient_ready: result.recipient_ready,
            reason_codes: result.reason_codes,
            eligible_endpoint_count: result.eligible_endpoint_count,
            resolved_endpoint_id: result.resolved_endpoint_id,
            correlation_id: Contract::Observability::Correlation.resolve,
          )
        end
      end
    end
  end
end
