# frozen_string_literal: true

module CommandTower
  module UI
    module Fragments
      # Base class for a host's shared fact block. The pinned entry point is
      # `Facts.call(f, metadata:)`: `f` is the Builder, `metadata` is the host's
      # data. It emits exactly one `facts` node; the subclass fills it by
      # implementing `compose(b, metadata:)` with primitives (or other fragments).
      #
      #   class ClassFacts < CommandTower::UI::Fragments::Facts
      #     def compose(b, metadata:)
      #       b.text(metadata.fetch(:title), variant: :title)
      #       b.key_value { |kv| kv.item "Where", metadata.fetch(:where) }
      #     end
      #   end
      #
      #   ClassFacts.call(d, metadata: { title: "Yoga", where: "Studio B" })
      class Facts
        def self.call(builder, metadata:)
          new.call(builder, metadata:)
        end

        def call(builder, metadata:)
          builder.facts { |inner| compose(inner, metadata:) }
        end

        # Subclasses implement this.
        def compose(_builder, metadata:)
          raise NotImplementedError, "#{self.class.name} must implement compose(builder, metadata:)"
        end
      end
    end
  end
end
