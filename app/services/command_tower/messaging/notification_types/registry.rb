# frozen_string_literal: true

module CommandTower
  module Messaging
    module NotificationTypes
      class Registry
        def self.instance
          @instance ||= new
        end

        def self.reset!
          @instance = new
        end

        def initialize
          @declarations = {}
          @sealed = false
          @mutex = Mutex.new
        end

        def register(declaration)
          @mutex.synchronize do
            raise SealedRegistryError, "notification type registry is sealed" if @sealed

            DeclarationValidator.validate!(declaration)
            DeclarationValidator.validate_category_consistency!(declaration, peers: @declarations.values)

            key = declaration.key
            if @declarations.key?(key)
              raise DuplicateTypeError, "notification type already registered: #{key}"
            end

            @declarations[key] = declaration
            declaration
          end
        end

        def seal
          @mutex.synchronize do
            validate_sealed_catalog!

            @sealed = true
            @declarations = @declarations.dup.freeze
            true
          end
        end

        def sealed?
          @sealed
        end

        def lookup(key)
          declaration = @declarations[key.to_s]
          raise NotFoundError, "notification type not registered: #{key}" if declaration.nil?

          declaration
        end

        def registered?(key)
          @declarations.key?(key.to_s)
        end

        def enumerate
          @declarations.values.freeze
        end

        def catalog
          groups = @declarations.values.group_by(&:category_key)
          categories = groups.map do |category_key, declarations|
            sample = declarations.first
            ordered = declarations.sort_by { |declaration| type_sort_key(declaration) }
            CatalogCategory.build(
              key: category_key,
              label: sample.category_label,
              order: sample.category_order,
              declarations: ordered,
            )
          end

          categories.sort_by! { |category| [category.order, category.key] }
          categories.freeze
        end

        private

        def validate_sealed_catalog!
          @declarations.each_value do |declaration|
            DeclarationValidator.validate!(declaration)
          end

          validate_sound_references!

          @declarations.each_value do |declaration|
            peers = @declarations.values.reject { |peer| peer.equal?(declaration) || peer.key == declaration.key }
            DeclarationValidator.validate_category_consistency!(declaration, peers:)
          end

          validate_home_deep_link_configuration!
        end

        # Sound ids are checked at seal, not register, so host initializer order cannot matter.
        def validate_sound_references!
          catalog_errors = SoundCatalog.validation_errors
          raise InvalidDeclarationError, "invalid sound catalog: #{catalog_errors.join('; ')}" if catalog_errors.any?

          @declarations.each_value do |declaration|
            errors = DeclarationValidator.sound_reference_errors(declaration, catalog_ids: SoundCatalog.ids)
            raise InvalidDeclarationError, "#{declaration.key}: #{errors.join('; ')}" if errors.any?
          end
        end

        # Presence only. A Proc is configured and is not called here.
        def validate_home_deep_link_configuration!
          return if CommandTower.config.messaging.expo.adapter.to_s == "disabled"
          return unless @declarations.values.any? { |declaration| declaration.allowed_channels.include?("push") }
          return if CommandTower.config.messaging.expo.home_deep_link_configured?

          raise InvalidDeclarationError,
            "home_deep_link must be configured when a push-capable type is registered and the Expo adapter is enabled"
        end

        def type_sort_key(declaration)
          [declaration.type_order, declaration.key]
        end
      end
    end
  end
end
