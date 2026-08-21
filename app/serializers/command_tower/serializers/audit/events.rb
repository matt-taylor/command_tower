# frozen_string_literal: true

module CommandTower
  module Serializers
    module Audit
      module Events
        class EventSerializer < CommandTower::Serializers::ApplicationSerializer
          def self.serialize(projection)
            {
              id: projection.fetch(:id),
              eventName: projection.fetch(:event_name),
              eventLabel: projection.fetch(:event_label),
              occurredAt: iso8601(projection.fetch(:occurred_at)),
              attributionMode: projection.fetch(:attribution_mode),
              actor: { userId: projection[:actor_user_id] },
              affectedUser: { userId: projection[:affected_user_id] },
              subject: {
                type: projection[:subject_type],
                id: projection[:subject_id],
                label: projection[:subject_label]
              },
              impersonationActive: projection.fetch(:impersonation_active),
              originatingAdministratorId: projection[:originating_administrator_id],
              changes: projection.fetch(:changes),
              metadata: projection.fetch(:metadata)
            }
          end
        end

        class PaginationMetaSerializer < CommandTower::Serializers::ApplicationSerializer
          def self.serialize(pagination)
            {
              limit: pagination.fetch(:limit),
              offset: pagination.fetch(:offset),
              totalCount: pagination.fetch(:total_count)
            }
          end
        end
      end
    end
  end
end
