# frozen_string_literal: true

module CommandTower
  module Clients
    # Validation-capable endpoint argument objects.
    # Construct once in EndpointBase; do not mutate after construction (convention).
    # Untyped attributes only — typing/validation policy deferred.
    class EndpointInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      def ==(other)
        other.instance_of?(self.class) && attributes == other.attributes
      end
      alias eql? ==
    end
  end
end
