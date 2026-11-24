# frozen_string_literal: true

require "command_tower/rspec/message_definition"

RSpec.describe CommandTower::Testing::MessageDefinitionRendering do
  describe "express_required_facts" do
    it "passes for the studio-zone sample's default fixture" do
      expect(ClassCanceled).to express_required_facts(fixture: :default)
    end

    it "passes for the studio-zone sample's other-zone fixture" do
      expect(ClassCanceled).to express_required_facts(fixture: :other_zone)
    end

    it "passes for the user-zone sample" do
      expect(MembershipRenewal).to express_required_facts
    end

    it "passes for the code sample" do
      expect(CheckInReady).to express_required_facts
    end

    it "fails for class_reminder because its SMS leaves out starts_at" do
      expect(ClassReminder).not_to express_required_facts(fixture: :default)
    end

    context "with a failing definition" do
      subject(:matcher) { express_required_facts }

      before { matcher.matches?(ClassReminder) }

      it "names the channel and fact key in the failure message, without values" do
        expect(matcher.failure_message).to include("sms_body is missing starts_at")
      end
    end

    it "rejects an unknown fixture" do
      expect { express_required_facts(fixture: :missing).matches?(ClassCanceled) }
        .to raise_error(ArgumentError, /no fixture "missing"/)
    end
  end

  describe "have_fact_block_once" do
    it "passes for every sample's inbox and email" do
      expect([ClassCanceled, MembershipRenewal, ClassReminder, CheckInReady]).to all(have_fact_block_once)
    end

    it "fails for a document without a fact block" do
      expect(CommandTower::UI.document(text_fallback: "x") { |d| d.text("Hello") }).not_to have_fact_block_once
    end
  end

  describe "exclude_code_from_email" do
    it "passes when the email has no code" do
      expect(ClassCanceled).to exclude_code_from_email
    end

    it "fails for check_in_ready, whose email composer includes the code" do
      expect(CheckInReady).not_to exclude_code_from_email
    end
  end
end
