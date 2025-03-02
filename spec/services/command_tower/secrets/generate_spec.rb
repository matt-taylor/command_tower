# frozen_string_literal: true

RSpec.describe CommandTower::Secrets::Generate do
  let(:user) { create(:user) }
  let(:instance) { described_class.new(**params) }
  before do
    allow(described_class).to receive(:new).and_return(instance)
  end
  let(:params) do
    {
      user:,
      reason:,
      type:,
      extra:,
      death_time:,
      use_count_max:,
      secret_length: 12,
      cleanse:,
    }.compact
  end

  let(:cleanse) { false }
  let(:secret_length) { nil }
  let(:reason) { CommandTower::Secrets::ALLOWED_SECRET_REASONS.sample }
  let(:type) { nil }
  let(:extra) { nil }
  let(:death_time) { nil }
  let(:use_count_max) { nil }

  describe ".call" do
    subject(:call) { described_class.(**params) }

    shared_examples "default examples" do
      shared_examples "with deathable" do
        context "with extra" do
          let(:extra) { "this is a custom reason that will get saved" }

          it do
            expect(call.record.extra).to eq(extra)
          end
        end

        context "with duplicate secret" do
          let(:secret) { described_class.(**params).secret }
          let(:attempt_count) { described_class::MAX_RETRY - 1 }
          before do
            secrets = attempt_count.times.map { secret }
            allow(instance).to receive(:generate_secret).and_return(*secrets, "actual unique value")
          end

          it "succeeds" do
            expect(call.success?).to eq(true)
            expect(call.secret).to be_present
            expect(call.record).to be_a(UserSecret)
          end

          it "sets secret" do
            expect { call }.to change(UserSecret, :count).by(1)
          end

          context "when retries exhausted" do
            let(:attempt_count) { described_class::MAX_RETRY }

            it "fails" do
              expect(call.failure?).to eq(true)
            end

            it "does not set secret" do
              expect { call }.to_not change(UserSecret, :count)
            end
          end
        end

        context "with cleanse" do
          let(:cleanse) { true }

          it "cleanses old keys" do
            expect(CommandTower::Secrets::Cleanse).to receive(:call).and_call_original

            subject
          end
        end
      end

      context "with death_time" do
        let(:death_time) { rand(1...1_000).hours }

        include_examples "with deathable"
      end

      context "with use_count_max" do
        let(:use_count_max) { rand(1...1_000) }

        include_examples "with deathable"
      end

      context "with both death_time and use_count_max" do
        let(:use_count_max) { rand(1...1_000) }
        let(:death_time) { rand(1...1_000).hours }

        it "sets both" do

          expect(subject.record.death_time).to be_present
          expect(subject.record.use_count_max).to be_present
        end

        include_examples "with deathable"
      end
    end

    context "with :alphanumeric" do
      let(:type) { :alphanumeric }

      include_examples "default examples"
    end

    context "with :hex" do
      let(:type) { :alphanumeric }

      include_examples "default examples"
    end

    context "with :numeric" do
      let(:type) { :numeric }

      include_examples "default examples"
    end
  end
end
