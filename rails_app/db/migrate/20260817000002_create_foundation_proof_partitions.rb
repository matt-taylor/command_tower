# frozen_string_literal: true

class CreateFoundationProofPartitions < ActiveRecord::Migration[7.1]
  def change
    create_table :foundation_proof_partitions do |t|
      t.string :slug, null: false
      t.string :label, null: false
      t.timestamps
    end

    add_index :foundation_proof_partitions, :slug, unique: true

    create_table :foundation_proof_user_partitions do |t|
      t.references :user, null: false, index: true
      t.references :foundation_proof_partition, null: false, index: true
      t.timestamps
    end

    add_index :foundation_proof_user_partitions,
      %i[user_id foundation_proof_partition_id],
      unique: true,
      name: "index_fp_user_partitions_on_user_and_partition"
  end
end
