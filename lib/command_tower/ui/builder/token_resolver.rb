# frozen_string_literal: true

module CommandTower
  module UI
    class Builder
      # Validates token arguments for a primitive. Unknown tokens raise
      # InvalidTokenError in development and test. In production they fall back
      # to the field's default and log the node path and a code only, never the
      # value.
      module TokenResolver
        # Token fields per primitive: field => [allowed values, default].
        FIELDS = {
          stack: { gap: [Tokens::GAP, "md"], align: [Tokens::ALIGN, nil] },
          card: { surface: [Tokens::SURFACE, "raised"], tone: [Tokens::TONE, nil], padding: [Tokens::GAP, "md"] },
          text: { variant: [Tokens::VARIANT, "body"], text_tone: [Tokens::TEXT_TONE, "primary"] },
          time: {
            variant: [Tokens::VARIANT, "body"], text_tone: [Tokens::TEXT_TONE, "primary"],
            format: [Nodes::Instant::FORMAT, "short"], label: [Nodes::Instant::LABEL, "auto"]
          },
          badge: { tone: [Tokens::TONE, "neutral"] },
          button: { variant: [Tokens::BUTTON_VARIANT, "secondary"] },
          image: { fit: [Nodes::Image::FIT, "cover"] },
          banner: { tone: [Tokens::TONE, "neutral"] },
          avatar: { size: [Tokens::AVATAR_SIZE, "md"] },
          stat_tile: { tone: [Tokens::TONE, nil] },
          code: { format: [Nodes::Code::FORMAT, nil] }
        }.freeze

        module_function

        # Returns attributes with token values normalized to strings.
        def call(type, node_path, attributes)
          FIELDS.fetch(type, {}).each do |field, (allowed, default)|
            next if attributes[field].nil?

            field_path = "#{node_path}.#{field.to_s.camelize(:lower)}"
            attributes[field] = resolve(attributes[field], allowed, default, field_path)
          end
          attributes
        end

        def resolve(value, allowed, default, field_path)
          token = value.to_s
          return token if allowed.include?(token)

          raise InvalidTokenError, "unknown token at #{field_path}" if Rails.env.local?

          Rails.logger.warn { "[CommandTower::UI::Builder] #{field_path}: unknown_token, using default" }
          default
        end
      end
    end
  end
end
