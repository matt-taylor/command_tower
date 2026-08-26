# frozen_string_literal: true

module CommandTower
  module Services
    module Admin
      module Users
        class List < CommandTower::Services::ApplicationService
          validate :limit, is_a: Integer, required: true, gte: 1, lte: 100
          validate :offset, is_a: Integer, required: true, gt: -1
          validate :search, is_a: String, required: false
          validate :principal, is_a: User, required: false
          validate :scope_context, is_a: [CommandTower::AdminScope::ScopeContext, NilClass], required: false

          def call
            relation = ::User.not_deleted.order(id: :desc)
            relation = CommandTower::AdminScope::ApplyUsersNarrowing.call(
              relation:,
              scope_context:,
              principal: principal || scope_context_principal
            )
            relation = apply_search(relation)

            context.users = relation.limit(limit).offset(offset).to_a
            context.pagination = { limit:, offset:, total_count: relation.count }
          end

          private

          def scope_context_principal
            principal
          end

          def apply_search(relation)
            token = search.to_s.strip
            return relation if token.empty?

            pattern = "%#{ActiveRecord::Base.sanitize_sql_like(token)}%"
            relation.where(
              "email LIKE :q OR username LIKE :q OR first_name LIKE :q OR last_name LIKE :q",
              q: pattern
            )
          end
        end

        class Show < CommandTower::Services::ApplicationService
          validate :id, is_a: Integer, required: true
          validate :principal, is_a: User, required: false
          validate :scope_context, is_a: [CommandTower::AdminScope::ScopeContext, NilClass], required: false

          def call
            relation = ::User.not_deleted.where(id:)
            relation = CommandTower::AdminScope::ApplyUsersNarrowing.call(
              relation:,
              scope_context:,
              principal: principal || scope_context_principal
            )
            user = relation.first
            if user.nil?
              return context.fail!(application_error: CommandTower::Errors::NotFoundError.new)
            end

            context.user = user
          end

          private

          def scope_context_principal
            principal
          end
        end

        module IdentityUniqueness
          DUPLICATE_MESSAGE = "has already been taken"

          module_function

          def uniqueness_error(field)
            CommandTower::Errors::ValidationError.new(details: { field => DUPLICATE_MESSAGE })
          end

          def uniqueness_taken?(error, attribute)
            record = error.respond_to?(:record) ? error.record : nil
            return false if record.nil?

            Array(record.errors.details[attribute]).any? { |entry| entry[:error] == :taken }
          end
        end

        class UpdateName < CommandTower::Services::ApplicationService
          validate :user, is_a: User, required: true
          validate :first_name, is_a: String, required: true
          validate :last_name, is_a: String, required: true

          def call
            normalized_first = first_name.to_s.strip
            normalized_last = last_name.to_s.strip
            first_changed = normalized_first != user.first_name.to_s
            last_changed = normalized_last != user.last_name.to_s

            unless first_changed || last_changed
              context.user = user
              context.changed = false
              return
            end

            application_error = nil

            ActiveRecord::Base.transaction do
              if first_changed
                application_error = mutate(first_name: normalized_first)
                raise ActiveRecord::Rollback if application_error
              end

              if last_changed
                application_error = mutate(last_name: normalized_last)
                raise ActiveRecord::Rollback if application_error
              end
            end

            if application_error
              context.fail!(application_error:)
              return
            end

            context.user = user.reload
            context.changed = true
          end

          private

          def mutate(**attribute)
            result = CommandTower::UserAttributes::Mutate.call(user:, **attribute)
            return nil if result.success?

            details = result.invalid_argument_hash.transform_values { _1[:msg].to_s }
            CommandTower::Errors::ValidationError.new(details: camelize_detail_keys(details))
          rescue ActiveRecord::RecordInvalid => error
            uniqueness_or_raise(error, attribute.keys.first)
          rescue ActiveRecord::RecordNotUnique
            IdentityUniqueness.uniqueness_error(camelize_field(attribute.keys.first))
          end

          def uniqueness_or_raise(error, attribute)
            if IdentityUniqueness.uniqueness_taken?(error, attribute)
              return IdentityUniqueness.uniqueness_error(camelize_field(attribute))
            end

            raise error
          end

          def camelize_detail_keys(details)
            details.transform_keys { |key| camelize_field(key) }
          end

          def camelize_field(field)
            case field.to_s
            when "first_name" then "firstName"
            when "last_name" then "lastName"
            else field.to_s
            end
          end
        end

        class UpdateUsername < CommandTower::Services::ApplicationService
          validate :user, is_a: User, required: true
          validate :username, is_a: String, required: true

          def call
            normalized = username.to_s.strip
            if user.username.to_s == normalized
              context.user = user
              context.changed = false
              return
            end

            result = CommandTower::UserAttributes::Mutate.call(user:, username: normalized)
            unless result.success?
              details = result.invalid_argument_hash.transform_values { _1[:msg].to_s }
              context.fail!(application_error: CommandTower::Errors::ValidationError.new(details:))
              return
            end

            context.user = user.reload
            context.changed = true
          rescue ActiveRecord::RecordInvalid => error
            fail_uniqueness_or_raise(error)
          rescue ActiveRecord::RecordNotUnique
            context.fail!(application_error: IdentityUniqueness.uniqueness_error("username"))
          end

          private

          def fail_uniqueness_or_raise(error)
            if IdentityUniqueness.uniqueness_taken?(error, :username)
              context.fail!(application_error: IdentityUniqueness.uniqueness_error("username"))
              return
            end

            raise error
          end
        end

        class UpdateEmail < CommandTower::Services::ApplicationService
          validate :user, is_a: User, required: true
          validate :email, is_a: String, required: true

          def call
            normalized = email.to_s.strip
            if user.email.to_s == normalized
              context.user = user
              context.changed = false
              return
            end

            result = CommandTower::UserAttributes::Mutate.call(user:, email: normalized)
            unless result.success?
              details = result.invalid_argument_hash.transform_values { _1[:msg].to_s }
              context.fail!(application_error: CommandTower::Errors::ValidationError.new(details:))
              return
            end

            user.reload
            user.update!(email_validated: false) if user.email_validated

            context.user = user
            context.changed = true
          rescue ActiveRecord::RecordInvalid => error
            fail_uniqueness_or_raise(error)
          rescue ActiveRecord::RecordNotUnique
            context.fail!(application_error: IdentityUniqueness.uniqueness_error("email"))
          end

          private

          def fail_uniqueness_or_raise(error)
            if IdentityUniqueness.uniqueness_taken?(error, :email)
              context.fail!(application_error: IdentityUniqueness.uniqueness_error("email"))
              return
            end

            raise error
          end
        end

        class SetEmailValidated < CommandTower::Services::ApplicationService
          validate :user, is_a: User, required: true
          validate :email_validated, is_a: [TrueClass, FalseClass], required: true

          def call
            if user.email_validated == email_validated
              context.user = user
              context.changed = false
              return
            end

            user.update!(email_validated:)
            context.user = user
            context.changed = true
          end
        end

        class ListAssignableRoles < CommandTower::Services::ApplicationService
          def call
            context.roles = CommandTower::Authorization::AssignableRoles.catalog
          end
        end

        class RoleAssignmentPolicy < CommandTower::Services::ApplicationService
          validate :actor, is_a: User, required: true
          validate :target, is_a: User, required: true
          validate :desired_roles, is_a: Array, required: true

          def call
            desired = desired_roles.map(&:to_s)
            assignable = CommandTower::Authorization::AssignableRoles.names

            if desired.any? { |name| protected_role?(name) }
              return context.fail!(application_error: CommandTower::Errors::ForbiddenError.new)
            end

            unknown = desired.reject { |name| assignable.include?(name) }
            if unknown.any?
              return context.fail!(
                application_error: CommandTower::Errors::ValidationError.new(
                  details: { roles: "unknown_or_unassignable" }
                )
              )
            end

            current = Array(target.roles).map(&:to_s)
            current_assignable = current.select { |name| assignable.include?(name) }
            newly_assigned = desired - current_assignable
            actor_grants = CommandTower::Authorization::EffectiveEntityGrants.for_user(actor)

            newly_assigned.each do |role_name|
              candidate_grants = CommandTower::Authorization::EffectiveEntityGrants.for_role(role_name)
              next if CommandTower::Authorization::EffectiveEntityGrants.subset?(candidate_grants, actor_grants)

              return context.fail!(application_error: CommandTower::Errors::ForbiddenError.new)
            end

            preserved = current.reject { |name| assignable.include?(name) }
            proposed = preserved + desired.uniq

            if target.id == actor.id && self_lockout?(actor_grants, proposed)
              return context.fail!(application_error: CommandTower::Errors::ForbiddenError.new)
            end

            context.desired_roles = desired.uniq
          end

          private

          def protected_role?(name)
            role = CommandTower::Authorization::Role.roles[name]
            name.to_s == CommandTower::Authorization::AssignableRoles::OWNER_NAME ||
              role&.allow_everything
          end

          def self_lockout?(before_grants, proposed_role_names)
            grants = CommandTower::Authorization::EffectiveEntityGrants
            after_grants = grants.for_role_names(proposed_role_names)

            if grants.includes?(before_grants, "admin_rbac_assignments") &&
                !grants.includes?(after_grants, "admin_rbac_assignments")
              return true
            end

            grants.includes?(before_grants, "admin_workspace") &&
              !grants.includes?(after_grants, "admin_workspace")
          end
        end

        class ReplaceUserRoles < CommandTower::Services::ApplicationService
          validate :user, is_a: User, required: true
          validate :desired_roles, is_a: Array, required: true

          def call
            assignable = CommandTower::Authorization::AssignableRoles.names
            desired = desired_roles.map(&:to_s).uniq
            current = Array(user.roles).map(&:to_s)
            current_assignable = current.select { |name| assignable.include?(name) }
            preserved = current.reject { |name| assignable.include?(name) }
            next_roles = (preserved + desired).uniq

            assigned = desired - current_assignable
            revoked = current_assignable - desired
            changed = assigned.any? || revoked.any?

            unless changed
              context.user = user
              context.assigned_roles = []
              context.revoked_roles = []
              context.changed = false
              return
            end

            user.roles = next_roles
            unless user.save
              return context.fail!(
                application_error: CommandTower::Errors::ValidationError.new(
                  details: { roles: "could_not_save" }
                )
              )
            end

            context.user = user
            context.assigned_roles = assigned
            context.revoked_roles = revoked
            context.changed = true
          end
        end
      end
    end
  end
end

