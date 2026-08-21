# frozen_string_literal: true

RSpec.describe CommandTower::Logging::Subscriber do
  after { CommandTower::Current.reset }

  describe "audit isolation" do
    let(:messages) { [] }
    let(:user) { create(:user) }

    before do
      %i[debug info warn error].each do |level|
        allow(Rails.logger).to receive(level) do |message|
          messages << { level:, message: }
        end
      end
      CommandTower::Current.user_id = user.id
      CommandTower::Audit::Emit.call(
        name: :password_changed,
        subject: user,
        affected_user: user,
        changes: {},
        scope_class: :global
      )
    end

    it "does not materialize audit events" do
      expect(
        messages.select { |entry| entry[:message].is_a?(Hash) && entry[:message][:event].to_s.start_with?("command_tower.audit") }
      ).to eq([])
    end
  end
end
