# frozen_string_literal: true

module CommandTower
  module PaginationServiceHelper
    def query
      return default_query if pagination_params.empty?

      context.pagination_used = true

      default_query.offset(pagination_params[:offset]).limit(pagination_params[:limit])
    end

    def default_query
      raise NoMethodError, "Method must be defined on base class"
    end

    def pagination_schema
      return nil unless context.pagination_used

      base_params = {
        limit: pagination_params[:limit],
        cursor: pagination_params[:offset],
      }
      query = base_params.to_query
      current = CommandTower::Schema::Page.new(query:, **base_params)

      base_params[:cursor] += pagination_params[:limit]
      query = base_params.to_query
      next_page = CommandTower::Schema::Page.new(query:, **base_params)

      count_available = default_query.size
      total_pages = count_available / pagination_params[:limit]
      # when offset is zero, it returns 0...Min page is 1
      base_current_page = (pagination_params[:offset].to_f / pagination_params[:limit].to_f)
      if pagination_params[:offset] % pagination_params[:limit] == 0
        current_page = (base_current_page + 1).to_i
      else
        current_page = base_current_page.ceil
      end
      # current_page = [, 1].max
      # Ensure we cannot go negative when no elements are returned
      remaining_pages = [total_pages - current_page, 0].max

      CommandTower::Schema::Pagination.new(
        count_available:,
        total_pages:,
        current_page:,
        remaining_pages:,
        current:,
        next: next_page,
      )
    end

    def pagination_params
      return {} if context.pagination.presence.nil?

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
