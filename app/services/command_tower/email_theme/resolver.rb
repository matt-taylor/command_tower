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
        colors.merge(
          product_name: CommandTower.app_name_for_comms,
          product_url: CommandTower.config.application.composed_url
        ).freeze
      end

      private

      # Derived from the host token file only when it exists (design D19);
      # otherwise exactly today's config.email_theme values.
      def colors
        return Palette.legacy_keys_from(Palette.resolve) if TokenFile.host_file?

        theme = CommandTower.config.email_theme
        Palette::LEGACY_TO_PALETTE.keys.index_with { |key| theme.public_send(key) }
      end
    end
  end
end
