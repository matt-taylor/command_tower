# frozen_string_literal: true

module CommandTower
  module HomeNotices
    module Campaigns
      # Built-in dismissible campaign `ct.update_app` (design D10). Shown only while the client
      # compatibility recommendation says `updateAvailable`, and again for each new recommended
      # version. It is separate from the 426 gate, which this class never touches. Included in the
      # catalog when `config.home_notices.update_app_campaign` is true; the key is reserved for it.
      class UpdateApp < Campaign
        TITLE = "A new version is ready"
        BODY = "Update to get the latest fixes and improvements."
        BODY_WITHOUT_URL = "Update from your device's app store to get the latest fixes and improvements."
        BUTTON_LABEL = "Update now"

        key "ct.update_app"
        severity :dismissible
        priority 100
        impressions max: 3, cooldown: 24.hours

        # A new recommended version starts a new period, so impressions and acknowledgement reset.
        period_key { |user:, context:| Recommendation.new(context.client_compatibility).recommended_version } # rubocop:disable Lint/UnusedBlockArgument

        def show?(user:, context:, notice:) # rubocop:disable Lint/UnusedMethodArgument
          Recommendation.new(context.client_compatibility).update_available?
        end

        def compose(builder, user:, context:, notice:) # rubocop:disable Lint/UnusedMethodArgument
          recommendation = Recommendation.new(context.client_compatibility)
          url = recommendation.https_update_url

          body = url ? BODY : BODY_WITHOUT_URL
          builder.stack(gap: :md) do |stack|
            stack.fragment(CommandTower::UI::Fragments::NoticeFrame, title: TITLE, body: [body])
            add_versions(stack, your_version: context.app_version, latest: recommendation.recommended_version)
            stack.button(BUTTON_LABEL, action: stack.navigate(href: url), variant: :primary) if url
          end
        end

        private

        def add_versions(builder, your_version:, latest:)
          return if your_version.blank? && latest.blank?

          builder.key_value do |rows|
            rows.item("Your version", your_version.to_s) if your_version.present?
            rows.item("Latest", latest.to_s) if latest.present?
          end
        end

        # Reads the `Current.client_compatibility_recommendation` projection (symbol or string keys).
        class Recommendation
          def initialize(projection)
            @projection = projection.respond_to?(:with_indifferent_access) ? projection.with_indifferent_access : {}
          end

          def update_available?
            @projection[:updateAvailable] == true
          end

          def recommended_version
            @projection[:recommendedVersion].presence&.to_s
          end

          # The update URL when it is an https URL the document can carry, else nil.
          def https_update_url
            url = @projection[:updateUrl].to_s
            return nil unless url.start_with?("https://")
            return nil if CommandTower::UI::Hardening.external_href_code(url)

            url
          end
        end
      end
    end
  end
end
