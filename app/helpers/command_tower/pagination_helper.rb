# frozen_string_literal: true

module CommandTower
  module PaginationHelper
    def pagination_values
      (pagination_from_body || pagination_from_query || {}).compact
    end

    def pagination_from_body
      pagination = params[:pagination]
      return nil unless pagination.is_a?(ActionController::Parameters) || pagination.is_a?(Hash)

      {
        page: pagination_safe_integer_convert(pagination[:page]),
        limit: pagination_safe_integer_convert(pagination[:limit]),
        cursor: pagination_safe_integer_convert(pagination[:cursor]),
      }
    end

    def pagination_from_query
      return nil unless safe_boolean(value: params[:pagination]) == true

      {
        page: pagination_safe_integer_convert(params[:page]),
        limit: pagination_safe_integer_convert(params[:limit]),
        cursor: pagination_safe_integer_convert(params[:cursor]),
      }
    end

    def pagination_safe_integer_convert(value, type = Integer)
      return if value.presence.nil?

      if value.to_i.to_s == value
        value.to_i
      else
        nil
      end
    end
  end
end
