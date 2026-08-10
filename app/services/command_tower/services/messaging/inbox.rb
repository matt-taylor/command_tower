# frozen_string_literal: true

module CommandTower
  module Services
    module Messaging
      module Inbox
        module FailureMapping
          private

          def with_recipient
            result = CommandTower::Services::Messaging::Recipients.call(user:)
            return context.fail!(application_error: result.errors.first) unless result.success?

            yield result.data[:recipient_id]
          rescue CommandTower::Messaging::Inbox::InvalidBulkItemsError => error
            context.fail!(application_error: CommandTower::Errors::ValidationError.new(details: { messaging: error.message, invalid_ids: error.invalid_ids }))
          rescue CommandTower::Messaging::Inbox::ValidationError, CommandTower::Messaging::Contract::ValidationError => error
            context.fail!(application_error: CommandTower::Errors::ValidationError.new(details: { messaging: error.message }))
          rescue CommandTower::Messaging::Inbox::NotFoundError
            context.fail!(application_error: CommandTower::Errors::NotFoundError.new)
          rescue CommandTower::Messaging::Inbox::InvariantError, CommandTower::Messaging::Contract::NotFoundError,
                 CommandTower::Messaging::Inbox::Error, CommandTower::Messaging::Contract::Error
            context.fail!(application_error: CommandTower::Errors::InternalError.new)
          end
        end

        class List < CommandTower::Services::ApplicationService
          include FailureMapping
          validate :user, is_a: User, required: true
          validate :limit, is_a: Integer, required: true
          validate :offset, is_a: Integer, required: true
          validate :scope, is_a: String, required: false, default: "inbox"

          def call
            with_recipient do |recipient_id|
              result = CommandTower::Messaging::Inbox.list(recipient_id:, limit:, offset:, scope:)
              context.items = result.items.map { |item| Inbox.item(item) }
              context.pagination = { limit: result.limit, offset: result.offset, total_count: result.total_count }
            end
          end
        end

        class Show < CommandTower::Services::ApplicationService
          include FailureMapping
          validate :user, is_a: User, required: true
          validate :inbox_item_id, is_a: Integer, required: true

          def call
            with_recipient { |recipient_id| context.item = Inbox.detail(recipient_id:, inbox_item_id:) }
          end
        end

        class Open < Show
          def call
            with_recipient do |recipient_id|
              Inbox.detail(recipient_id:, inbox_item_id:)
              CommandTower::Messaging::Inbox.mark_viewed(recipient_id:, inbox_item_id:)
              context.item = Inbox.detail(recipient_id:, inbox_item_id:)
            end
          end
        end

        class Archive < CommandTower::Services::ApplicationService
          include FailureMapping
          validate :user, is_a: User, required: true
          validate :inbox_item_id, is_a: Integer, required: true

          def call
            with_recipient { |recipient_id| context.item = Inbox.item(CommandTower::Messaging::Inbox.archive(recipient_id:, inbox_item_id:)) }
          end
        end

        class Delete < CommandTower::Services::ApplicationService
          include FailureMapping
          validate :user, is_a: User, required: true
          validate :inbox_item_id, is_a: Integer, required: true

          def call
            with_recipient { |recipient_id| CommandTower::Messaging::Inbox.delete(recipient_id:, inbox_item_id:) }
          end
        end

        class UnreadCount < CommandTower::Services::ApplicationService
          include FailureMapping
          validate :user, is_a: User, required: true

          def call
            with_recipient { |recipient_id| context.count = CommandTower::Messaging::Inbox.unread_count(recipient_id:).count }
          end
        end

        module BulkMutation
          def call
            with_recipient do |recipient_id|
              result = yield(recipient_id)
              context.bulk_result = { ids: result.ids, count: result.count, changed_count: result.changed_count }
            end
          end
        end

        %i[Read Unread Archive Restore Delete].each do |action|
          operation = "bulk_#{action.to_s.downcase == "read" ? "mark_viewed" : action.to_s.downcase == "unread" ? "mark_unviewed" : action.to_s.downcase}"
          const_set(:"Bulk#{action}", Class.new(CommandTower::Services::ApplicationService) do
            include FailureMapping
            include BulkMutation
            validate :user, is_a: User, required: true
            validate :inbox_item_ids, is_a: Array, required: true

            define_method(:call) { super() { |recipient_id| CommandTower::Messaging::Inbox.public_send(operation, recipient_id:, inbox_item_ids:) } }
          end)
        end

        class << self
          def item(item)
            { id: item.id, title: item.title, status: item.status, viewed_at: item.viewed_at, created_at: item.created_at, updated_at: item.updated_at }
          end

          def detail(recipient_id:, inbox_item_id:)
            item = CommandTower::Messaging::Inbox.show(recipient_id:, inbox_item_id:)
            communication = CommandTower::Messaging::Contract::Communications.find(
              CommandTower::Messaging::Contract::Requests::FindCommunication.build(communication_id: item.communication_id, recipient_id:)
            )
            item(item).merge(body: communication.body, metadata: communication.metadata, notification_type_key: communication.notification_type_key)
          end
        end
      end
    end
  end
end
