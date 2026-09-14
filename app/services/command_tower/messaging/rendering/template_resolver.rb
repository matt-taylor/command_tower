# frozen_string_literal: true

require "action_view"

module CommandTower
  module Messaging
    module Rendering
      # Internal Execution-pipeline collaborator (not a Service/Workflow/Controller).
      #
      # Resolves one rendered-destination basename (e.g. "email", "sms") to an
      # ActionView template, preferring a `notification_type_key`-specific view
      # over the generic one, and preferring the host application's `app/views`
      # over CommandTower's own engine views for either.
      #
      # Host convention (documentation, not code):
      #
      #   app/views/command_tower/messaging/rendering/
      #     email.html.erb                     # optional host override of the generic chrome
      #     <notification_type_key>/email.html.erb  # optional type-specific override
      #
      # Hosts customize by dropping ERB files at that path; they never call this
      # class directly. `ChannelRenderer` remains the only public Ruby entry into
      # rendering. `prepend_view_path`/`reset_view_paths!` exist solely as a
      # messaging spec fixture seam (mirrors Rails' own `prepend_view_path`
      # testing idiom) and are not part of any host-facing contract.
      class TemplateResolver
        TEMPLATE_PREFIX = "command_tower/messaging/rendering"
        TYPE_KEY_PATTERN = /\A[a-z0-9_]+\z/

        class << self
          def render(basename:, format:, notification_type_key:, generic_locals:, type_locals:)
            new.render(
              basename:,
              format:,
              notification_type_key:,
              generic_locals:,
              type_locals:,
            )
          end

          # Spec-only seam: prepend an additional view root ahead of the host
          # and engine defaults so fixture views can prove override precedence.
          def prepend_view_path(path)
            extra_view_paths.unshift(path.to_s)
          end

          def reset_view_paths!
            extra_view_paths.clear
          end

          # Type-only, no-generic-fallback resolution: returns `nil` when
          # there is no matching type template (invalid/sanitized-out key, or
          # the type directory/basename simply does not exist) instead of
          # raising `Errno::ENOENT` like `.render` does. Callers that have no
          # generic ERB file to fall back to (e.g. `InboxDocumentRenderer`,
          # whose generic path is a pure-Ruby builder) use this instead of
          # `.render`. A template that is *found* but raises mid-render still
          # propagates (via `render_named`'s `ActionView::Template::Error`
          # unwrap) so callers can distinguish "no type content" from "type
          # content is broken" if they choose to.
          def render_type_template(basename:, format:, notification_type_key:, locals:)
            new.render_type_template(basename:, format:, notification_type_key:, locals:)
          end

          def extra_view_paths
            @extra_view_paths ||= []
          end
        end

        def render(basename:, format:, notification_type_key:, generic_locals:, type_locals:)
          type_key = sanitized_type_key(notification_type_key)

          if type_key
            begin
              return render_named("#{TEMPLATE_PREFIX}/#{type_key}/#{basename}", format, type_locals)
            rescue ActionView::MissingTemplate
              # No type-specific template for this basename; fall through to generic.
            end
          end

          begin
            render_named("#{TEMPLATE_PREFIX}/#{basename}", format, generic_locals)
          rescue ActionView::MissingTemplate
            raise Errno::ENOENT, "missing template #{basename}.#{format}.erb"
          end
        end

        def render_type_template(basename:, format:, notification_type_key:, locals:)
          type_key = sanitized_type_key(notification_type_key)
          return nil unless type_key

          render_named("#{TEMPLATE_PREFIX}/#{type_key}/#{basename}", format, locals)
        rescue ActionView::MissingTemplate
          nil
        end

        private

        def sanitized_type_key(notification_type_key)
          key = notification_type_key.to_s
          key.match?(TYPE_KEY_PATTERN) ? key : nil
        end

        def render_named(template_name, format, locals)
          view.render(template: template_name, formats: [format], locals:)
        rescue ActionView::Template::Error => error
          # ActionView wraps any error raised while executing a *found*
          # template in `ActionView::Template::Error`. Legacy plain-ERB
          # rendering never wrapped errors, so unwrap here to preserve the
          # original `error_class` that `ChannelRenderer#render`'s outer
          # rescue surfaces on `RenderError`.
          raise(error.cause || error)
        end

        def view
          @view ||= ActionView::Base.with_empty_template_cache.with_view_paths(view_paths)
        end

        def view_paths
          self.class.extra_view_paths + [
            Rails.root.join("app/views").to_s,
            CommandTower::Engine.root.join("app/views").to_s,
          ]
        end
      end
    end
  end
end
