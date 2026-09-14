# frozen_string_literal: true

module CommandTower
  module EmailTheme
    # Internal rendering-time collaborator (not a Service/Workflow/Controller).
    #
    # Assembles the full semantic token set an email template needs: the
    # visual tokens from CommandTower.config.email_theme plus the identity
    # tokens CommandTower already exposes (config.application). Shared by
    # Messaging email templates and, later, CT's own auth mail templates —
    # hence its own top-level namespace rather than living under
    # Messaging::Rendering.
    #
    # No template calls this yet (Rich Messaging Strategy §12 steps C/D are
    # separate, later slices). This is deliberately not a
    # CommandTower::Services::ApplicationService: it takes no arguments,
    # performs no I/O, and cannot fail under normal config state — there is
    # nothing to validate and nothing to fail. Mirrors
    # Messaging::Rendering::TemplateResolver's own documented exemption.
    class Resolver
      class << self
        def resolve
          new.resolve
        end
      end

      def resolve
        theme = CommandTower.config.email_theme
        {
          canvas_background: theme.canvas_background,
          surface_background: theme.surface_background,
          surface_border: theme.surface_border,
          primary_text: theme.primary_text,
          body_text: theme.body_text,
          muted_text: theme.muted_text,
          accent: theme.accent,
          text_on_accent: theme.text_on_accent,
          primary_action: theme.primary_action,
          product_name: CommandTower.app_name_for_comms,
          product_url: CommandTower.config.application.composed_url
        }.freeze
      end
    end
  end
end
