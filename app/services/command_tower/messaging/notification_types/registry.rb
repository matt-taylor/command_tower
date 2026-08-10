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

          @declarations.each_value do |declaration|
            peers = @declarations.values.reject { |peer| peer.equal?(declaration) || peer.key == declaration.key }
            DeclarationValidator.validate_category_consistency!(declaration, peers:)
          end
        end

        def type_sort_key(declaration)
          [declaration.type_order, declaration.key]
        end
      end
    end
  end
end
