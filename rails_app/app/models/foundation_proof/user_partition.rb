# frozen_string_literal: true

module FoundationProof
  class UserPartition < ApplicationRecord
    self.table_name = "foundation_proof_user_partitions"

    belongs_to :user
    belongs_to :partition,
      class_name: "FoundationProof::Partition",
      foreign_key: :foundation_proof_partition_id,
      inverse_of: :user_partitions

    validates :user_id, uniqueness: { scope: :foundation_proof_partition_id }
  end
end
