# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::PlainText::Login do
  describe ".call" do
    subject(:result) { described_class.call(identifier: identifier, password: password) }

    let(:password) { "password1234" }
    let(:user) { create(:user, password: password, email: "service-login@example.com", username: "svclogin") }
    let(:identifier) { user.email }

    before { user }

    context "with valid credentials" do
      let(:token_sid) { CommandTower::Jwt::Decode.call(token: result.data[:token]).payload[:sid] }

      it "returns a successful ServiceResult" do
        expect(result).to be_a(CommandTower::Services::ServiceResult)
        expect(result).to be_success
      end

      it "returns user, token, and expires_at in data" do
        expect(result.data[:user]).to eq(user)
        expect(result.data[:token]).to be_present
        expect(result.data[:expires_at]).to be_present
      end

      it "starts a device session and puts its sid in the token" do
        expect(token_sid).to eq(result.data[:device_session].public_id)
        expect(result.data[:device_session].user_id).to eq(user.id)
      end

      it "records the successful login on the user" do
        expect { result }.to change { user.reload.successful_login }.by(1)
      end
    end

    context "with invalid credentials" do
      subject(:result) { described_class.call(identifier: identifier, password: attempt_password) }

      let(:attempt_password) { "wrong-password" }

      it "returns a failed ServiceResult" do
        expect(result).to be_failure
      end

      it "returns InvalidCredentialsError" do
        expect(result.errors).to contain_exactly(
          an_instance_of(CommandTower::Errors::Auth::InvalidCredentialsError)
        )
      end

      context "when login_failed is enabled" do
        before { CommandTower.config.registry.audit.set_enabled!(:login_failed, true) }

        it "persists login_failed for a known user without the identifier" do
          expect { result }.to change { CommandTower::Audit::Event.where(action: "login_failed").count }.by(1)
        end

        context "when inspecting the login_failed row" do
          before { result }

          let(:row) { CommandTower::Audit::Event.find_by!(action: "login_failed") }

          it "records the known user without the identifier" do
            expect(row.affected_user_id).to eq(user.id)
            expect(row.attribution_mode).to eq("system")
            expect(row.metadata).to eq("outcome" => "invalid_password")
            expect(row.metadata.values.join).not_to include(user.email)
            expect(row.metadata.values.join).not_to include(identifier)
          end
        end
      end
    end

    describe "timing equalization" do
      let(:bcrypt_calls) { [] }

      before do
        described_class.dummy_digest
        allow(BCrypt::Engine).to receive(:hash_secret).and_wrap_original do |original, *args|
          bcrypt_calls << args
          original.call(*args)
        end
      end

      it "does one bcrypt comparison for a known user with a wrong password" do
        described_class.call(identifier: user.email, password: "wrong-password")

        expect(bcrypt_calls.size).to eq(1)
      end

      it "does one bcrypt comparison for an unknown identifier" do
        described_class.call(identifier: "nobody@example.com", password: "wrong-password")

        expect(bcrypt_calls.size).to eq(1)
      end
    end

    describe "soft lockout" do
      let(:max) { CommandTower.config.login.rate_limits.account_failures }

      let(:rate_limited_error) { be_a(CommandTower::Errors::Auth::AuthRateLimitedError) }

      it "answers invalid credentials before the threshold" do
        expect(Array.new(max - 1) { login_attempt(identifier: user.email, password: "wrong").errors.first })
          .to all(be_a(CommandTower::Errors::Auth::InvalidCredentialsError))
      end

      it "answers auth_rate_limited with retry_after_seconds when a failure trips the lock", :aggregate_failures do
        expect(trip_login_lock(user.email).errors.first).to rate_limited_error
        expect(login_attempt(identifier: user.email, password: "wrong").errors.first.details[:retry_after_seconds])
          .to be_between(1, 900)
      end

      it "rejects a correct password while locked" do
        trip_login_lock(user.email)

        expect(login_attempt(identifier: user.email, password: password).errors)
          .to contain_exactly(an_instance_of(CommandTower::Errors::Auth::AuthRateLimitedError))
      end

      it "shares one counter between email and username" do
        (max / 2).times { login_attempt(identifier: user.email, password: "wrong") }
        (max - (max / 2) - 1).times { login_attempt(identifier: user.username, password: "wrong") }

        expect(login_attempt(identifier: user.username, password: "wrong").errors.first).to rate_limited_error
      end

      it "does not count failures while locked" do
        trip_login_lock(user.email)

        expect { 5.times { login_attempt(identifier: user.email, password: "wrong") } }
          .not_to(change { user.reload.password_consecutive_fail })
      end

      it "clears the failure streak on success", :aggregate_failures do
        (max - 1).times { login_attempt(identifier: user.email, password: "wrong") }
        expect(login_attempt(identifier: user.email, password: password)).to be_success

        (max - 1).times { login_attempt(identifier: user.email, password: "wrong") }
        expect(login_attempt(identifier: user.email, password: password)).to be_success
      end

      it "locks an unknown identifier exactly like a known one", :aggregate_failures do
        trip_login_lock(user.email)

        expect(trip_login_lock("nobody@example.com").errors.first).to rate_limited_error
        expect(login_attempt(identifier: "NOBODY@example.com", password: "x").errors.first).to rate_limited_error
      end

      context "when counting bcrypt comparisons while locked" do
        before do
          trip_login_lock(user.email)
          allow(BCrypt::Engine).to receive(:hash_secret).and_call_original
        end

        it "does one bcrypt comparison" do
          login_attempt(identifier: user.email, password: password)

          expect(BCrypt::Engine).to have_received(:hash_secret).once
        end
      end

      context "with a per-IP ceiling" do
        before { allow(CommandTower.config.login.rate_limits).to receive(:ip_attempts).and_return(2) }

        it "applies it when a client_ip is given" do
          2.times { described_class.call(identifier: user.email, password: "wrong", client_ip: "198.51.100.7") }

          expect(described_class.call(identifier: user.email, password:, client_ip: "198.51.100.7").errors.first)
            .to rate_limited_error
        end
      end

      context "when Redis is down" do
        before { allow(CommandTower::RedisConnection).to receive(:with).and_raise(Redis::CannotConnectError) }

        it "still signs in" do
          expect(login_attempt(identifier: user.email, password: password)).to be_success
        end
      end
    end

    context "with an unknown identifier" do
      subject(:result) { described_class.call(identifier: "nobody@example.com", password: "wrong-password") }

      before { CommandTower.config.registry.audit.set_enabled!(:login_failed, true) }

      it "persists login_failed without an affected user or identifier" do
        expect { result }.to change { CommandTower::Audit::Event.where(action: "login_failed").count }.by(1)
      end

      it "returns InvalidCredentialsError rather than a persistence failure" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(
          an_instance_of(CommandTower::Errors::Auth::InvalidCredentialsError)
        )
        expect(result.errors.map(&:class).map(&:name)).not_to include("ActiveRecord::CheckViolation")
      end

      context "when inspecting the unknown-identifier row" do
        before { result }

        let(:row) { CommandTower::Audit::Event.find_by!(action: "login_failed") }
        let(:raw_metadata) do
          CommandTower::Audit::Event.connection.select_value(
            CommandTower::Audit::Event.sanitize_sql_array([
              "SELECT metadata FROM command_tower_audit_events WHERE id = ?",
              row.id
            ])
          )
        end
        let(:raw_metadata_text) { raw_metadata.is_a?(String) ? raw_metadata : raw_metadata.to_json }

        it "omits affected user and identifier" do
          expect(row.affected_user_id).to be_nil
          expect(row.metadata).to eq("outcome" => "unknown_identifier")
          expect(row.metadata.values.join).not_to include("nobody@example.com")
        end

        it "stores metadata as JSON without Ruby Hash#inspect" do
          expect(raw_metadata_text).not_to include("=>")
          expect(JSON.parse(raw_metadata_text)).to eq("outcome" => "unknown_identifier")
        end
      end
    end
  end
end
