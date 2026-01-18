# frozen_string_literal: true

module CommandTower
  module SchemaHelper
    def schema_succesful!(schema:, status:)
      schema_hash = schema.to_h
      # Fix: Ensure pagination is an empty hash when nil or missing, so it responds to empty?
      # Only apply this fix to schemas that have a pagination field defined
      has_pagination_field = false
      if schema.class.respond_to?(:introspect)
        introspect_result = schema.class.introspect
        has_pagination_field = introspect_result.is_a?(Hash) && (introspect_result.key?(:pagination) || introspect_result.key?("pagination"))
      end

      # Also check if pagination key exists in the hash itself (fallback)
      has_pagination_in_hash = schema_hash.key?("pagination") || schema_hash.key?(:pagination)

      if has_pagination_field || has_pagination_in_hash
        # Check if pagination key exists (as string or symbol) and if value is nil
        pagination_val = schema_hash["pagination"] || schema_hash[:pagination]
        if pagination_val.nil?
          # Value is nil, set it to empty hash (use string key for consistency with JSON)
          schema_hash["pagination"] = {}
        end
      end
      render(json: schema_hash, status:)
    end

    def invalid_arguments!(message:, argument_object:, schema:, status:)
      bad_arguments = argument_object.map do |key, metadata|
        CommandTower::Schema::Error::InvalidArgument.new(
          schema:,
          argument: key,
          argument_type: metadata[:type],
          reason: metadata[:msg],
        )
      end

      result = CommandTower::Schema::Error::InvalidArgumentResponse.new(
        invalid_arguments: bad_arguments,
        invalid_argument_keys: argument_object.keys,
        status:,
        message:,
      )

      render(json: result.to_h, status:)
    end
  end
end
