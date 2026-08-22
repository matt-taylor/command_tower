# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::PlainText::Login do
  describe ".call" do
    subject(:result) { described_class.call(identifier: identifier, password: password) }

    let(:password) { "password1234" }
    let(:user) { create(:user, password: password, email: "service-login@example.com", username: "svclogin") }
    let(:identifier) { user.email }

    before { user }

    context "with valid credentials" do
      it "returns a successful ServiceResult" do
        expect(result).to be_a(CommandTower::Services::ServiceResult)
        expect(result).to be_success
      end

      it "returns user, token, and expires_at in data" do
        expect(result.data[:user]).to eq(user)
        expect(result.data[:token]).to be_present
        expect(result.data[:expires_at]).to be_present
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

        it "omits affected user and identifier" do
          expect(row.affected_user_id).to be_nil
          expect(row.metadata).to eq("outcome" => "unknown_identifier")
          expect(row.metadata.values.join).not_to include("nobody@example.com")
        end

        it "stores metadata as JSON without Ruby Hash#inspect" do
          raw = CommandTower::Audit::Event.connection.select_value(
            CommandTower::Audit::Event.sanitize_sql_array([
              "SELECT metadata FROM command_tower_audit_events WHERE id = ?",
              row.id
            ])
          )
          raw_text = raw.is_a?(String) ? raw : raw.to_json

          expect(raw_text).not_to include("=>")
          expect(JSON.parse(raw_text)).to eq("outcome" => "unknown_identifier")
        end
      end
    end
  end
end
