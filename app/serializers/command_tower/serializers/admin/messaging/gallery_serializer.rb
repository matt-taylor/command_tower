# frozen_string_literal: true

module CommandTower
  module Serializers
    module Admin
      module Messaging
        # Wire form of the admin message gallery (design 3.5). Keys are camelCase; channels the type
        # does not allow stay `null`.
        module GallerySerializer
          module_function

          def serialize_list(types)
            types.map { |type| list_item(type) }
          end

          def list_item(type)
            {
              "notificationTypeKey" => type[:notification_type_key], "label" => type[:label],
              "definition" => type[:definition], "allowedChannels" => type[:allowed_channels],
              "promotional" => type[:promotional],
              "fixtures" => type[:fixtures].map do |fixture|
                { "name" => fixture[:name], "metadataVersion" => fixture[:metadata_version] }
              end
            }
          end

          def serialize_preview(preview)
            {
              "notificationTypeKey" => preview[:notification_type_key],
              "fixture" => preview[:fixture],
              "metadataVersion" => preview[:metadata_version],
              "renderZone" => preview[:render_zone],
              "slots" => slots(preview[:slots]),
              "channels" => channels(preview[:channels]),
              "facts" => { "app" => preview.dig(:facts, :app), "emailHtml" => preview.dig(:facts, :email_html) },
              "checks" => preview[:checks].map { |check| check.transform_keys { |key| camelize(key) } }
            }
          end

          def slots(slots)
            {
              "headline" => slots[:headline], "subject" => slots[:subject], "pushBody" => slots[:push_body],
              "smsBody" => slots[:sms_body], "pushoverTitle" => slots[:pushover_title],
              "pushoverMessage" => slots[:pushover_message]
            }
          end

          def channels(channels)
            wire = %i[push sms pushover inbox].to_h { |name| [name.to_s, channels[name]&.transform_keys(&:to_s)] }
            wire.merge("email" => email(channels[:email]))
          end

          def email(email)
            return nil unless email

            { "subject" => email[:subject], "html" => email[:html], "text" => email[:text],
              "usedFallback" => email[:used_fallback] }
          end

          def camelize(key)
            key.to_s.camelize(:lower)
          end
        end
      end
    end
  end
end
