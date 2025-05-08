# frozen_string_literal: true

module CommandTower
  module AdminService
    class Users < CommandTower::ServiceBase
      include CommandTower::PaginationServiceHelper

      on_argument_validation :fail_early

      # to be used for auditing later maybe?
      validate :user, is_a: User, required: true

      def call
        schemafied_users = query.map { CommandTower::Schema::User.convert_user_object(user: _1) }
        context.schema = CommandTower::Schema::Admin::Users.new(
          users: schemafied_users,
          count: schemafied_users.count,
          pagination: pagination_schema,
        )
      end

      def default_query
        ::User.all.select(*CommandTower.config.user.default_attributes)
      end
    end
  end
end
