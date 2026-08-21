# frozen_string_literal: true

module FoundationProof
  class Partition < ApplicationRecord
    self.table_name = "foundation_proof_partitions"

    has_many :user_partitions,
      class_name: "FoundationProof::UserPartition",
      foreign_key: :foundation_proof_partition_id,
      dependent: :destroy,
      inverse_of: :partition

    has_many :users, through: :user_partitions

    validates :slug, :label, presence: true
    validates :slug, uniqueness: true
  end
end
