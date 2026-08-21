# frozen_string_literal: true

module FoundationProof
  module AdminScope
    HOST_CONTEXT_TYPE = "foundation_proof.partition"

    module_function

    def register!
      CommandTower.config.registry.admin_workspace.configure_tool(:users) do |tool|
        tool.scope_required = true
        tool.scope_parameter = "partition"
        tool.scope_label = "Partition"
      end

      CommandTower.config.registry.admin_workspace.configure_tool(:audit) do |tool|
        tool.scope_required = true
        tool.scope_parameter = "partition"
        tool.scope_label = "Partition"
      end

      register_tool(:users)
      register_tool(:audit)
    end

    def register_tool(tool_id)
      CommandTower.config.admin_scope.register(tool_id) do |registration|
        registration.options = method(:scope_options)
        registration.validate = method(:validate_scope)
        registration.availability = method(:availability)
        registration.narrow_users = method(:narrow_users)
        registration.narrow_audit = method(:narrow_audit)
        registration.affected_users_in_scope = method(:affected_users_in_scope)
        registration.host_context_type = HOST_CONTEXT_TYPE
      end
    end

    def scope_options(principal:)
      partitions_for(principal).map do |partition|
        CommandTower::AdminScope::ScopeOption.new(value: partition.slug, label: partition.label)
      end
    end

    def availability(principal:)
      options = scope_options(principal:)
      if options.empty?
        return { enabled: false, reason: "No administrable partitions" }
      end

      { enabled: true, reason: nil }
    end

    def validate_scope(value:, principal:)
      partitions_for(principal).any? { |partition| partition.slug == value.to_s }
    end

    def narrow_users(relation:, scope_value:, principal:, tool_id:)
      user_ids = user_ids_for_partition(scope_value)
      relation.where(id: user_ids)
    end

    def narrow_audit(relation:, scope_value:, principal:, tool_id:)
      relation.where(
        host_context_type: HOST_CONTEXT_TYPE,
        host_context_identifier: scope_value.to_s
      )
    end

    def affected_users_in_scope(scope_value:, principal:, tool_id:)
      user_ids_for_partition(scope_value)
    end

    def partitions_for(principal)
      FoundationProof::Partition
        .joins(:user_partitions)
        .where(foundation_proof_user_partitions: { user_id: principal.id })
        .distinct
        .order(:slug)
    end
    private_class_method :partitions_for

    def user_ids_for_partition(scope_value)
      partition = FoundationProof::Partition.find_by!(slug: scope_value.to_s)
      FoundationProof::UserPartition.where(foundation_proof_partition_id: partition.id).select(:user_id)
    end
    private_class_method :user_ids_for_partition
  end
end
