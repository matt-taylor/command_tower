# frozen_string_literal: true

module CommandTower
  module Services
    module ClientCompatibility
      # Pure, deterministic client-version-compatibility decision.
      #
      # Same (headers, controller/action, registry state) always produces the
      # same complete `Decision`. This service MUST NOT mutate
      # `CommandTower::Current` or any other request-global — it has zero side
      # effects beyond returning its result. Any placement of recommendation
      # metadata onto `Current` is transport plumbing that belongs to the
      # workflow or boundary layer, never here.
      class Evaluate
        DECISIONS = %i[compatible recommended incompatible identity_invalid].freeze

        # Immutable decision/projection. `recommendation_projection` is the
        # camelCase `clientCompatibility` shape (authority §13), present only
        # when identity is parseable and current >= effective minimum.
        class Decision
          attr_reader :decision, :platform, :current_version, :effective_minimum, :scope,
                      :recovery, :update_url, :matched_entity_names, :recommendation_projection

          def initialize(
            decision:,
            platform: nil,
            current_version: nil,
            effective_minimum: nil,
            scope: nil,
            recovery: nil,
            update_url: nil,
            matched_entity_names: [],
            recommendation_projection: nil
          )
            @decision = decision
            @platform = platform
            @current_version = current_version
            @effective_minimum = effective_minimum
            @scope = scope
            @recovery = recovery
            @update_url = update_url
            @matched_entity_names = matched_entity_names
            @recommendation_projection = recommendation_projection
          end

          def compatible? = %i[compatible recommended].include?(@decision)

          def incompatible? = !compatible?
        end

        def self.call(app_version_header:, platform_header:, controller_class:, action_name:, registry: CommandTower.config.registry.client_compatibility)
          new(
            app_version_header:,
            platform_header:,
            controller_class:,
            action_name:,
            registry:
          ).call
        end

        def initialize(app_version_header:, platform_header:, controller_class:, action_name:, registry:)
          @app_version_header = app_version_header
          @platform_header = platform_header
          @controller_class = controller_class
          @action_name = action_name.to_s
          @registry = registry
        end

        def call
          return no_op_decision unless registry.opted_in?

          platform = normalized_platform
          version = normalized_version
          return identity_invalid_decision(platform:) if platform.nil? || version.nil?

          policy = registry.platform_policy(platform)
          return identity_invalid_decision(platform:, current_version: version) if policy.nil?

          matched = matched_entity_names
          effective_minimum, scope = effective_minimum_and_scope(policy:, platform:, matched:)

          current = Gem::Version.new(version)
          minimum = Gem::Version.new(effective_minimum)

          if current < minimum
            return incompatible_decision(
              platform:, current_version: version, effective_minimum:, scope:, matched:, policy:
            )
          end

          compatible_or_recommended_decision(
            platform:, current_version: version, effective_minimum:, matched:, policy:, current:
          )
        end

        private

        attr_reader :controller_class, :action_name, :registry

        def normalized_platform
          token = @platform_header.to_s.strip.downcase
          return nil if token.empty?
          return nil unless CommandTower::Configuration::Registry::ClientCompatibility::Config::PLATFORMS.map(&:to_s).include?(token)

          token.to_sym
        end

        def normalized_version
          CommandTower::ClientCompatibility::Version.normalize(@app_version_header)
        end

        def matched_entity_names
          CommandTower::Authorization::Entity.entities.values
            .select { |entity| entity.matches?(controller: controller_class, method: action_name.to_sym) == true }
            .map { |entity| entity.name.to_s }
        end

        def effective_minimum_and_scope(policy:, platform:, matched:)
          strictest = policy.minimum
          scope = :application

          matched.each do |entity_name|
            requirement = registry.entity_requirement(entity_name)
            next if requirement.nil?

            entity_minimum = entity_minimum_for(requirement, platform:)
            next if entity_minimum.nil?

            if Gem::Version.new(entity_minimum) > Gem::Version.new(strictest)
              strictest = entity_minimum
              scope = :capability
            end
          end

          [strictest, scope]
        end

        def entity_minimum_for(requirement, platform:)
          if requirement.client_contract.present?
            binding = registry.binding_for(requirement.client_contract)
            binding&.for_platform(platform)
          else
            requirement.minimum.for_platform(platform)
          end
        end

        def no_op_decision
          Decision.new(decision: :compatible)
        end

        def identity_invalid_decision(platform: nil, current_version: nil)
          Decision.new(
            decision: :identity_invalid,
            platform:,
            current_version:,
            scope: :application,
            recovery: recovery_for(platform),
            update_url: update_url_for(platform)
          )
        end

        def incompatible_decision(platform:, current_version:, effective_minimum:, scope:, matched:, policy:)
          Decision.new(
            decision: :incompatible,
            platform:,
            current_version:,
            effective_minimum:,
            scope:,
            recovery: recovery_for(platform),
            update_url: update_url_for(platform),
            matched_entity_names: matched,
            recommendation_projection: nil
          )
        end

        def compatible_or_recommended_decision(platform:, current_version:, effective_minimum:, matched:, policy:, current:)
          recommended = policy.recommended
          update_available = recommended.present? && current < Gem::Version.new(recommended)

          Decision.new(
            decision: update_available ? :recommended : :compatible,
            platform:,
            current_version:,
            effective_minimum:,
            scope: :application,
            matched_entity_names: matched,
            recommendation_projection: recommendation_projection(
              platform:, current_version:, effective_minimum:, recommended:, update_available:
            )
          )
        end

        def recommendation_projection(platform:, current_version:, effective_minimum:, recommended:, update_available:)
          {
            platform: platform.to_s,
            currentVersion: current_version,
            minimumVersion: effective_minimum,
            recommendedVersion: recommended,
            updateAvailable: update_available,
            recovery: recovery_for(platform).to_s,
            updateUrl: update_url_for(platform)
          }.compact
        end

        def recovery_for(platform)
          return :reload if platform.nil? || platform == :web

          :app_store
        end

        def update_url_for(platform)
          return nil if platform.nil? || platform == :web

          registry.platform_policy(platform)&.update_url
        end
      end
    end
  end
end
