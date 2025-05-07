# frozen_string_literal: true

module CommandTower
  module PaginationServiceHelper
    def query
      return default_query if pagination_params.nil?

      default_query.offset(pagination_params[:offset]).limit(pagination_params[:limit])
    end

    def default_query
      raise NoMethodError, "Method must be defined on base class"
    end

    def pagination_params
      return {} if context.pagination.nil?

      __params = { limit: pagination_limit }
      if pagination_cursor
        # When cursor is provided, we take cursor and limit as injections
        __params[:offset] = pagination_cursor
      else
        # When cursor is not provided, use default of page and limit
        __params[:offset] = pagination_page * pagination_limit
      end

      __params.compact
    end

    def pagination_cursor
      return if context.pagination[:cursor].nil?

      # Cursor must be greater than or equal to 0
      [context.pagination[:cursor].to_i, 0].max
    end

    def pagination_page
      # Page must be greater than or equal to 0
      # Incoming page is 1 indexed -- must convert to 0 indexed to work properly
      [(context.pagination[:page] || 1).to_i, 1].max - 1
    end

    def pagination_limit
      return CommandTower.config.pagination.limit if context.pagination[:limit].nil?

      [context.pagination[:limit].to_i, 1].max
    end
  end
end
