# frozen_string_literal: true

RSpec.describe CommandTower::Services::Account::UpdatePhone do
  describe ".call" do
    subject(:result) { described_class.call(user:, phone_number:) }

    let(:user) { create(:user, :without_phone) }
    let(:phone_number) { "4155552671" }

    context "when setting a new phone" do
      it { expect(result).to be_success }

      it "stores E.164 and leaves it unverified" do
        result
        user.reload

        expect(user.phone_number).to eq("+14155552671")
        expect(user.phone_number_validated).to eq(false)
      end

      context "when persisting the audit fact" do
        before do
          CommandTower.with_execution(source: :http, user_id: user.id, effective_user_id: user.id) do
            described_class.call(user:, phone_number:)
          end
        end

        let(:row) { CommandTower::Audit::Event.find_by!(action: "phone_updated") }

        it "persists sensitive phone from/to" do
          expect(row.change_set).to eq("phone" => { "from" => nil, "to" => "+14155552671" })
          expect(row.sensitive_fields).to eq(["phone"])
          expect(row.affected_user_id).to eq(user.id)
        end
      end

      it "returns the updated user" do
        expect(result.data[:user]).to eq(user)
      end
    end

    context "when replacing with a different number" do
      let(:user) { create(:user, phone_number: "+14155552672", phone_number_validated: true) }
      let(:phone_number) { "+14155552671" }

      it "stores the new number and clears validation" do
        result
        user.reload

        expect(user.phone_number).to eq("+14155552671")
        expect(user.phone_number_validated).to eq(false)
      end
    end

    context "when the normalized number matches the current value" do
      let(:user) { create(:user, phone_number: "+14155552671", phone_number_validated: true) }
      let(:phone_number) { "(415) 555-2671" }

      it { expect(result).to be_success }

      it "preserves phone_number_validated" do
        result
        user.reload

        expect(user.phone_number).to eq("+14155552671")
        expect(user.phone_number_validated).to eq(true)
      end

      it "does not persist phone_updated" do
        expect { result }.not_to change { CommandTower::Audit::Event.where(action: "phone_updated").count }
      end
    end

    context "with an unparseable number" do
      let(:phone_number) { "nope" }

      it "returns a ValidationError naming the field" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::ValidationError)
        expect(result.errors.first.details).to eq(phoneNumber: "is invalid")
      end

      it "does not change the user" do
        expect { result }.not_to change { user.reload.attributes.slice("phone_number", "phone_number_validated") }
      end
    end

    context "with a blank number" do
      let(:phone_number) { "   " }

      it "returns a ValidationError naming the field" do
        expect(result).to be_failure
        expect(result.errors.first.details).to eq(phoneNumber: "is required")
      end
    end

    context "when another user already owns the number" do
      before { create(:user, phone_number: "+14155552671", phone_number_validated: false) }

      it "reports the number as taken" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::ValidationError)
        expect(result.errors.first.details).to eq(phoneNumber: described_class::DUPLICATE_MESSAGE)
      end
    end

    context "when a uniqueness race raises RecordNotUnique" do
      before do
        allow(user).to receive(:save!).and_raise(ActiveRecord::RecordNotUnique.new("Duplicate"))
      end

      it "maps to a stable duplicate failure" do
        expect(result).to be_failure
        expect(result.errors.first.details).to eq(phoneNumber: described_class::DUPLICATE_MESSAGE)
      end
    end

    context "without a phone number argument" do
      let(:phone_number) { nil }

      it { expect(result).to be_failure }
    end
  end
end
