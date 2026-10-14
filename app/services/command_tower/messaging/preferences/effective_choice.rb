# frozen_string_literal: true

module CommandTower
  module Messaging
    module Preferences
      # Resolves the urgency and sound a member actually gets, and the blocks
      # the preferences API returns. IOS reads this at send time. It does not send.
      class EffectiveChoice
        def self.call(declaration:, stored:)
          new(declaration:, stored:).call
        end

        def self.urgency_ids(choice)
          choice.permitted(NotificationTypes::URGENCY_LEVELS)
        end

        def self.sound_ids(choice)
          ids = choice.allowed == "all" ? SoundCatalog.ids : Array(choice.allowed)
          ids.select { |id| SoundCatalog.fetch(id) }
        end

        def self.selectable?(ids)
          ids.size > 1
        end

        def self.validate_write!(declaration:, field:, value:)
          choice = declaration.public_send(field)
          ids = field == :urgency ? urgency_ids(choice) : sound_ids(choice)
          unless value.is_a?(String) && !value.strip.empty?
            raise InvalidPreferenceStateError, "preference #{field} must be a string"
          end
          unless selectable?(ids)
            raise InvalidPreferenceWriteError, "#{field} is not selectable for notification type: #{declaration.key}"
          end
          return if ids.include?(value)

          raise InvalidPreferenceWriteError, "#{field} is not permitted: #{value}"
        end

        def initialize(declaration:, stored:)
          @declaration = declaration
          @stored = stored
        end

        def call
          {
            urgency: urgency_block,
            sound: sound_block,
          }
        end

        private

        def urgency_block
          choice = @declaration.urgency
          ids = self.class.urgency_ids(choice)
          {
            default: choice.default,
            allowed: ids,
            selectable: self.class.selectable?(ids),
            effective: resolve(stored: @stored&.urgency, ids:, fallback: choice.default),
          }
        end

        def sound_block
          choice = @declaration.sound
          ids = self.class.sound_ids(choice)
          {
            default: choice.default,
            allowed: ids.map { |id| { id:, label: SoundCatalog.fetch(id)[:label] } },
            selectable: self.class.selectable?(ids),
            effective: resolve_sound(ids, choice.default),
          }
        end

        def resolve(stored:, ids:, fallback:)
          return stored if stored && ids.include?(stored)

          fallback
        end

        def resolve_sound(ids, fallback)
          stored = @stored&.sound
          return stored if stored && ids.include?(stored)
          return fallback if ids.include?(fallback)

          SoundCatalog::SYSTEM_DEFAULT[:id]
        end
      end
    end
  end
end
