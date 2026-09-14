# frozen_string_literal: true

require "class_composer"

module CommandTower
  module Configuration
    module EmailTheme
      # Semantic email theme tokens shared by Messaging email templates and,
      # later, CT-owned auth mail templates. CT-owned, gem-level contract —
      # see Rich Messaging Strategy §12 (email theme sequence, step A).
      #
      # Deliberately holds only visual/color tokens. Product identity
      # (name/URL) already exists on Configuration::Application::Config and
      # is composed in by CommandTower::EmailTheme::Resolver, not duplicated
      # here. Defaults are the current unbranded hex values already
      # hardcoded in command_tower's generic email.html.erb and Pick'em's
      # incomplete_wager/email.html.erb, so introducing this contract is a
      # no-op until a template is switched to consume it.
      class Config < ::CommandTower::Configuration::Base
        include ClassComposer::Generator

        add_composer :canvas_background,
          allowed: String,
          default: "#f4f5f7",
          desc: "Outer email canvas background color"

        add_composer :surface_background,
          allowed: String,
          default: "#ffffff",
          desc: "Card/surface background color"

        add_composer :surface_border,
          allowed: String,
          default: "#e2e8f0",
          desc: "Card/surface border color"

        add_composer :primary_text,
          allowed: String,
          default: "#1a202c",
          desc: "Headline/primary text color"

        add_composer :body_text,
          allowed: String,
          default: "#4a5568",
          desc: "Body copy text color"

        add_composer :muted_text,
          allowed: String,
          default: "#718096",
          desc: "De-emphasized/secondary text color"

        add_composer :accent,
          allowed: String,
          default: "#2b6cb0",
          desc: "Single flat accent color (collapses any gradient to one value)"

        add_composer :text_on_accent,
          allowed: String,
          default: "#ffffff",
          desc: "Text/icon color rendered on top of the accent color"

        add_composer :primary_action,
          allowed: String,
          default: "#2b6cb0",
          desc: "Link/button primary-action color"
      end
    end
  end
end
