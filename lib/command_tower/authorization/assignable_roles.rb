# frozen_string_literal: true

module CommandTower
  module Authorization
    module AssignableRoles
      OWNER_NAME = "owner"

      module_function

      def catalog
        CommandTower::Authorization::Role.roles.values
          .select { |role| assignable?(role) }
          .sort_by { |role| role.name.to_s }
          .map do |role|
            { name: role.name.to_s, description: role.description.to_s }
          end
      end

      def names
        catalog.map { |entry| entry[:name] }.to_set
      end

      def assignable?(role)
        return false if role.nil?
        return false if role.allow_everything
        return false if role.name.to_s == OWNER_NAME

        role.source == :host
      end

      def assignable_name?(name)
        names.include?(name.to_s)
      end
    end
  end
end
