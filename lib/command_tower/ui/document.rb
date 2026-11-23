# frozen_string_literal: true

require "json"

module CommandTower
  module UI
    # Envelope { schema, catalog, root, textFallback } plus document-wide
    # validation. Errors carry node paths and codes only, never values
    # (a `code` value, spans and times must not reach logs or exceptions).
    #
    # `validate!(profile:)` is the seam for later rule sets (the blocking-notice
    # profile in Set 3 adds external-links-only). Only :default exists.
    class Document
      PROFILES = %i[default].freeze
      MESSAGE_ERROR_LIMIT = 10

      attr_reader :root, :text_fallback

      def initialize(root:, text_fallback:)
        @root = root
        @text_fallback = text_fallback
      end

      def catalog
        CATALOG
      end

      def as_json(_options = nil)
        {
          "schema" => SCHEMA,
          "catalog" => catalog,
          "root" => root.as_json,
          "textFallback" => text_fallback
        }
      end

      # Array of { path:, code: } hashes. Empty when the document is valid.
      def validation_errors(profile: :default)
        raise ArgumentError, "unknown validation profile" unless PROFILES.include?(profile)

        walker = Walker.new
        walker.check_envelope(self)
        walker.walk(root, "root", 1) if root.is_a?(Nodes::Node)
        walker.check_size(self)
        walker.details
      end

      def validate!(profile: :default)
        details = validation_errors(profile:)
        return self if details.empty?

        raise InvalidDocumentError.new(message_for(details), details:)
      end

      def inspect
        "#<#{self.class.name} catalog=#{catalog}>"
      end
      alias to_s inspect

      private

      def message_for(details)
        shown = details.first(MESSAGE_ERROR_LIMIT).map { |detail| "#{detail[:path]}:#{detail[:code]}" }
        extra = details.length > MESSAGE_ERROR_LIMIT ? " (+#{details.length - MESSAGE_ERROR_LIMIT} more)" : ""
        "Invalid UI document (#{details.length} errors): #{shown.join(', ')}#{extra}"
      end

      # Depth-first traversal collecting per-node ActiveModel errors and
      # document-wide limits.
      class Walker
        attr_reader :details

        def initialize
          @details = []
          @nodes = 0
          @components = 0
          @primary_buttons = 0
          @open_facts = []
          @structure_overflow = false
        end

        def check_envelope(document)
          add("root", :invalid_node) unless document.root.is_a?(Nodes::Node)
          fallback = document.text_fallback
          if !fallback.is_a?(String) || fallback.empty?
            add("textFallback", :blank)
          elsif fallback.length > Limits::MAX_TEXT_FALLBACK_LENGTH
            add("textFallback", :too_long)
          end
        end

        def walk(object, path, depth)
          return if @structure_overflow

          return if object.node? && reject_node?(object, path, depth)

          collect_errors(object, path)
          object.each_child { |relative, child| walk(child, "#{path}.#{relative}", depth + (child.node? ? 1 : 0)) }
          leave_node(object, path)
        end

        def check_size(document)
          return if @structure_overflow || @details.any? { |detail| detail[:code] == "too_deep" }

          add("document", :too_large) if JSON.generate(document.as_json).bytesize > Limits::MAX_BYTES
        end

        private

        # True when the walk must not descend into this node (limit breached).
        def reject_node?(node, path, depth)
          @nodes += 1
          code = limit_code(depth)
          if code
            @structure_overflow = true if code == :too_many_nodes
            add(path, code)
          else
            track(node, path)
          end
          !code.nil?
        end

        def limit_code(depth)
          return :too_many_nodes if @nodes > Limits::MAX_NODES

          :too_deep if depth > Limits::MAX_DEPTH
        end

        def track(node, path)
          @open_facts.each { |entry| entry[:count] += 1 }
          @open_facts.push({ path:, count: 0 }) if node.is_a?(Nodes::Facts)
          count_singletons(node, path)
        end

        def leave_node(object, path)
          return unless object.is_a?(Nodes::Facts)

          entry = @open_facts.pop
          add(path, :too_many_facts_nodes) if entry[:count] > Limits::MAX_FACTS_NODES
        end

        def count_singletons(node, path)
          if node.is_a?(Nodes::Component)
            @components += 1
            add(path, :multiple_components) if @components > 1
          elsif node.is_a?(Nodes::Button) && node.primary?
            @primary_buttons += 1
            add(path, :multiple_primary_buttons) if @primary_buttons > 1
          end
        end

        def collect_errors(object, path)
          object.valid?
          object.errors.each do |error|
            suffix = error.attribute == :base ? "" : ".#{error.attribute.to_s.camelize(:lower)}"
            add("#{path}#{suffix}", error.type)
          end
        end

        def add(path, code)
          @details << { path:, code: code.to_s }
        end
      end
      private_constant :Walker
    end
  end
end
