# frozen_string_literal: true

require "foundation_proof/admin_scope"

module CommandTower
  module FoundationProofScopedAdminHelper
    def register_foundation_proof_scoped_admin!
      FoundationProof::AdminScope.register!
    end

    def reset_platform_tool_scope_config!
      return unless CommandTower.config.respond_to?(:registry)

      # Re-seed unfrozen platform tools. Mutating frozen ToolDefinitions after
      # finalize! raises ClassComposer::Error and poisons order-random suites.
      CommandTower.config.registry.admin_workspace.reset_platform_tool_scope_config!
    end

    def seed_foundation_proof_partitions!(admin:, member_a:, member_b:)
      partition_a = FoundationProof::Partition.create!(slug: "scope-a", label: "Scope A")
      partition_b = FoundationProof::Partition.create!(slug: "scope-b", label: "Scope B")

      FoundationProof::UserPartition.create!(user: admin, partition: partition_a)
      FoundationProof::UserPartition.create!(user: admin, partition: partition_b)
      FoundationProof::UserPartition.create!(user: member_a, partition: partition_a)
      FoundationProof::UserPartition.create!(user: member_b, partition: partition_b)

      { partition_a:, partition_b: }
    end
  end
end

RSpec.configure do |config|
  config.include CommandTower::FoundationProofScopedAdminHelper

  config.after do
    reset_platform_tool_scope_config!
  end
end
