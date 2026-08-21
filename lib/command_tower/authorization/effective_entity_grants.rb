# frozen_string_literal: true

module CommandTower
  module Authorization
    # Composed RBAC graph → effective entity name sets.
    # Backend policy only. Not a frontend authorization shortcut.
    module EffectiveEntityGrants
      ALL = :all

      module_function

      def allow_everything?(user)
        Array(user.roles).any? do |role_name|
          role = CommandTower::Authorization::Role.roles[role_name]
          role&.allow_everything
        end
      end

      def for_user(user)
        return ALL if allow_everything?(user)

        for_role_names(Array(user.roles))
      end

      def for_role_names(role_names)
        names = Array(role_names).map(&:to_s)
        if names.any? { |name| CommandTower::Authorization::Role.roles[name]&.allow_everything }
          return ALL
        end

        names.each_with_object(Set.new) do |name, grants|
          role = CommandTower::Authorization::Role.roles[name]
          next unless role

          role.entities.each { |entity| grants << entity.name.to_s }
        end
      end

      def for_role(role_name)
        for_role_names([role_name])
      end

      def includes?(grants, entity_name)
        grants == ALL || grants.include?(entity_name.to_s)
      end

      def subset?(candidate_grants, actor_grants)
        return true if actor_grants == ALL
        return false if candidate_grants == ALL

        candidate_grants.subset?(actor_grants)
      end
    end
  end
end
