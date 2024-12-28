# frozen_string_literal: true

module ApiEngineBase
  module SchemaHelper
    def schema_succesful!(schema:, status:)
      render(json: schema.to_h, status:)
    end

    def invalid_arguments!(message:, argument_object:, schema:, status:)
      bad_arguments = argument_object.map do |key, metadata|
        ApiEngineBase::Schema::Error::InvalidArgument.new(
          schema:,
          argument: key,
          argument_type: metadata[:type],
          reason: metadata[:msg],
        )
      end

      result = ApiEngineBase::Schema::Error::InvalidArgumentResponse.new(
        invalid_arguments: bad_arguments,
        invalid_argument_keys: argument_object.keys,
        status:,
        message:,
      )

      render(json: result.to_h, status:)
    end
  end
end
