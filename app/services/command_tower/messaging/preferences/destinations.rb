# frozen_string_literal: true

module CommandTower
  module Messaging
    module Preferences
      class Destinations
        REASONS = {
          "required" => "This notification is required on this destination.",
          "locked_on" => "This destination is locked on.",
          "locked_off" => "This destination is locked off.",
          "unavailable" => "This destination is unavailable.",
        }.freeze

        DestinationEntry = Data.define(:state, :effective, :reason_code, :reason)

        def self.call(declaration:, evaluation:, available_channels:)
          new(declaration:, evaluation:, available_channels:).call
        end

        def initialize(declaration:, evaluation:, available_channels:)
          @declaration = declaration
          @evaluation = evaluation
          @available_channels = Array(available_channels).map(&:to_s).freeze
          @locks = declaration.destination_locks || {}.freeze
          @defaults = PreferenceState.from_declaration_default(declaration.default_preference_state)
        end

        def call
          ChannelCatalog.entries_for(@declaration).to_h do |entry|
            key = entry[:key]
            [key, resolve(key).to_h.freeze]
          end.freeze
        end

        private

        def resolve(key)
          if key == "inbox"
            resolve_inbox
          else
            resolve_channel(key)
          end
        end

        def resolve_channel(channel)
          if unavailable_external?(channel)
            return build_entry(state: "unavailable", effective: false, reason_code: "unavailable")
          end

          lock = @locks[channel]
          return build_entry(state: "forced_off", effective: false, reason_code: "locked_off") if lock == "forced_off"
          return build_entry(state: "forced_on", effective: true, reason_code: "locked_on") if lock == "forced_on"

          member_on = member_channel_enabled?(channel)
          if mandatory_required_channel?(channel) && !member_on
            return build_entry(state: "forced_on", effective: true, reason_code: "required")
          end

          build_entry(state: "editable", effective: member_on, reason_code: nil)
        end

        def resolve_inbox
          lock = @locks["inbox"]
          return build_entry(state: "forced_off", effective: false, reason_code: "locked_off") if lock == "forced_off"
          return build_entry(state: "forced_on", effective: true, reason_code: "locked_on") if lock == "forced_on"

          member_on = member_inbox_enabled?
          if mandatory_required_inbox? && !member_on
            return build_entry(state: "forced_on", effective: true, reason_code: "required")
          end

          build_entry(state: "editable", effective: member_on, reason_code: nil)
        end

        def unavailable_external?(channel)
          @declaration.allowed_channels.include?(channel) && !@available_channels.include?(channel)
        end

        def mandatory_required_channel?(channel)
          @declaration.mandatory &&
            (@declaration.default_channels & @declaration.allowed_channels).include?(channel)
        end

        def mandatory_required_inbox?
          @declaration.mandatory && @declaration.inbox_available && @defaults.inbox != false
        end

        def member_channel_enabled?(channel)
          state = @evaluation.effective_preference_state || {}
          channels = state["channels"] || {}
          if channels.key?(channel)
            !!channels[channel]
          else
            @defaults.channel_enabled?(channel, default: true)
          end
        end

        def member_inbox_enabled?
          state = @evaluation.effective_preference_state || {}
          if state.key?("inbox")
            !!state["inbox"]
          elsif @defaults.inbox.nil?
            true
          else
            @defaults.inbox
          end
        end

        def build_entry(state:, effective:, reason_code:)
          reason = reason_code.nil? ? nil : REASONS.fetch(reason_code)
          DestinationEntry.new(
            state:,
            effective: !!effective,
            reason_code:,
            reason:,
          )
        end
      end
    end
  end
end
