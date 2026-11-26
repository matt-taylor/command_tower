# frozen_string_literal: true

namespace :command_tower do
  namespace :user_secrets do
    desc "Digest and blank legacy plaintext user_secrets.secret values (idempotent, batched)"
    task clear_plaintext: :environment do
      cleared = 0

      UserSecret.where.not(secret: nil).find_each(batch_size: 1_000) do |record|
        attributes = { secret: nil }
        attributes[:secret_digest] = UserSecret.digest_for(record.secret) if record.secret_digest.blank?

        # update_columns skips callbacks and timestamps; rows keep their issue time.
        record.update_columns(attributes) # rubocop:disable Rails/SkipsModelValidations
        cleared += 1
      end

      puts "Cleared plaintext from #{cleared} user secret(s)."
    end
  end
end
