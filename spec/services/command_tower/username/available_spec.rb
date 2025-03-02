# frozen_string_literal: true

RSpec.describe CommandTower::Username::Available do
  describe ".call" do
    subject(:call) { described_class.(username:, force_query:) }

    before do
      CommandTower.config.username.realtime_username_check.local_cache.clear
    end
    let(:username) { Faker::Lorem.word }
    let(:force_query) { false }

    context "when force reload!" do
      let(:force_query) { true }

      it "re-populates cache" do
        expect(User).to receive(:pluck)

        call
      end
    end

    context "when cache refresh is missing" do
      before do
        CommandTower.config.username.realtime_username_check.local_cache.clear
      end

      it "re-populates cache" do
        expect(User).to receive(:pluck)

        call
      end
    end

    context "when cache is old" do
      before do
        travel = CommandTower.config.username.realtime_username_check.local_cache_ttl.to_i
        Timecop.travel(travel)
      end

      it "re-populates cache" do
        expect(User).to receive(:pluck)

        call
      end
    end

    context "when username is available" do
      it "succeeds" do
        expect(call.success?).to eq(true)
      end

      it "sets available" do
        expect(call.available).to eq(true)
      end

      context "when username is not valid" do
        let(:username) { "Invalid.invalid" }

        it "succeeds" do
          expect(call.success?).to eq(true)
        end

        it "sets valid to false" do
          expect(call.valid).to eq(false)
        end

        it "sets available to false" do
          expect(call.available).to eq(true)
        end
      end
    end

    context "when username is not available" do
      let!(:user) { create(:user) }
      let(:username) { user.username }

      before do
        CommandTower.config.username.realtime_username_check.local_cache.clear
      end

      it "succeeds" do
        expect(call.success?).to eq(true)
      end

      it "sets available to false" do
        expect(call.available).to eq(false)
      end

      context "when username is not valid" do
        let!(:user) { create(:user, username:) }
        let(:username) { "Invalid.invalid" }

        it "succeeds" do
          expect(call.success?).to eq(true)
        end

        it "sets valid to false" do
          expect(call.valid).to eq(false)
        end

        it "sets available to false" do
          expect(call.available).to eq(false)
        end
      end
    end
  end
end
