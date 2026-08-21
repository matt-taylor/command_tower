# frozen_string_literal: true

RSpec.describe CommandTower::Services::Account::ClearPhone do
  describe ".call" do
    subject(:result) { described_class.call(user:) }

    context "when the user has a phone" do
      let(:user) { create(:user, phone_number: "+14155552671", phone_number_validated: true) }

      it { expect(result).to be_success }

      it "clears the phone and its validation" do
        result
        user.reload

        expect(user.phone_number).to be_nil
        expect(user.phone_number_validated).to eq(false)
      end

      context "when persisting the audit fact" do
        before do
          CommandTower.with_execution(source: :http, user_id: user.id, effective_user_id: user.id) do
            described_class.call(user:)
          end
        end

        let(:row) { CommandTower::Audit::Event.find_by!(action: "phone_cleared") }

        it "persists sensitive phone from/to" do
          expect(row.change_set).to eq("phone" => { "from" => "+14155552671", "to" => nil })
          expect(row.sensitive_fields).to eq(["phone"])
        end
      end

      it "returns the updated user" do
        expect(result.data[:user]).to eq(user)
      end
    end

    context "when the user has no phone" do
      let(:user) { create(:user, :without_phone) }

      it { expect(result).to be_success }

      it "leaves the phone blank and unverified" do
        result
        user.reload

        expect(user.phone_number).to be_nil
        expect(user.phone_number_validated).to eq(false)
      end

      it "does not persist phone_cleared" do
        expect { result }.not_to change { CommandTower::Audit::Event.where(action: "phone_cleared").count }
      end
    end
  end
end
