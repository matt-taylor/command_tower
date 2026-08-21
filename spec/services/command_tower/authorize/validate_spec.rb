# frozen_string_literal: true

RSpec.describe CommandTower::Authorize::Validate do
  before do
    CommandTower::Authorization::Role.roles_reset!
    CommandTower::Authorization::Entity.entities_reset!
    CommandTower::Authorization.default_defined!
  end

  after do
    CommandTower::Authorization::Role.roles_reset!
    CommandTower::Authorization::Entity.entities_reset!
    CommandTower::Authorization.default_defined!
  end

  describe ".call" do
    subject(:call) { described_class.call(user:, controller:, method:) }
    let(:controller) { CommandTower::Admin::Messaging::AnnouncementsController }
    let(:method) { "create" }

    let(:user) { create(:user, :role_admin) }

    it "succeeds" do
      expect(call.success?).to be(true)
    end

    it "sets context variables" do
      expect(call.authorization_required).to be(true)
      expect(call.msg).to eq("User is Authorized for action")
    end

    context "with action that does not require authorization" do
      let(:controller) { CommandTower::Auth::LogoutController }
      let(:method) { "create" }

      it "succeeds" do
        expect(call.success?).to be(true)
      end

      it "sets context variables" do
        expect(call.authorization_required).to be(false)
        expect(call.msg).to eq("Authorization not required at this time")
      end
    end


    context "when user has multiple conflicting roles with at least 1 authorized" do
      let(:user) { create(:user, :admin_roles) }

      it "succeeds" do
        expect(call.success?).to be(true)
      end

      it "sets context variables" do
        expect(call.authorization_required).to be(true)
        expect(call.msg).to eq("User is Authorized for action")
      end
    end


    context "when user does not have correct authorization" do
      let(:user) { create(:user) }

      it "fails" do
        expect(call.failure?).to be(true)
      end

      it "sets context variables" do
        expect(call.authorization_required).to be(true)
        expect(call.msg).to eq("Unauthorized Access. Incorrect User Privileges")
      end
    end

    describe "diagnostic events" do
      let(:log_events) { [] }
      let(:log_subscriber) do
        events = log_events
        ActiveSupport::Notifications.subscribe(/\Acommand_tower\.log\./) do |name, _s, _f, _id, payload|
          events << { name:, message: payload[:message] }
        end
      end

      before { log_subscriber }
      after { unsubscribe_notifications(log_subscriber) }

      it "publishes authorization success diagnostics at debug" do
        call
        expect(log_events.map { |event| event[:name] }).to include("command_tower.log.debug")
        expect(log_events.map { |event| event[:name] }).not_to include("command_tower.log.info")
        expect(log_events.map { |event| event[:message] }.join).to include("User Roles")
      end

      context "when user does not have correct authorization" do
        let(:user) { create(:user) }

        it "publishes a warning on denial" do
          call
          expect(log_events).to include(
            a_hash_including(name: "command_tower.log.warn", message: a_string_matching(/Unauthorized Access/))
          )
        end
      end
    end
  end
end
