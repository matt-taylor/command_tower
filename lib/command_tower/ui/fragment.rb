# frozen_string_literal: true

require "active_model"

module CommandTower
  module UI
    # Base class for reusable, parameterized pieces of a document. A fragment
    # declares inputs with `attribute` and `validates`, and `compose(b)` emits
    # primitives only, through the Builder. Fragments are referenced by constant
    # (`d.fragment(MyFragment, **inputs)`); there is no registry (design D3).
    #
    #   class FactRow < CommandTower::UI::Fragment
    #     attribute :label, :string
    #     attribute :value, :string
    #     validates :label, :value, presence: true
    #
    #     def compose(b)
    #       b.key_value { |kv| kv.item label, value }
    #     end
    #   end
    #
    # Invalid inputs raise InvalidFragmentError at construction. The error
    # carries attribute names and error codes only, never input values.
    class Fragment
      include ActiveModel::Model
      include ActiveModel::Attributes
      include ActiveModel::Validations

      def initialize(**inputs)
        super
        raise InvalidFragmentError, invalid_message unless valid?
      rescue ActiveModel::UnknownAttributeError => e
        raise InvalidFragmentError, "#{self.class.name}: unknown input #{e.attribute}"
      end

      # Emits primitives into the builder. Subclasses implement this.
      def compose(_builder)
        raise NotImplementedError, "#{self.class.name} must implement compose(builder)"
      end

      def inspect
        "#<#{self.class.name}>"
      end
      alias to_s inspect

      private

      def invalid_message
        codes = errors.map { |error| "#{error.attribute}:#{error.type}" }
        "#{self.class.name}: invalid inputs (#{codes.join(', ')})"
      end
    end
  end
end
