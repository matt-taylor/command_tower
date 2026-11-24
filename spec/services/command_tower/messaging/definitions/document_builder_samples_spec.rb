# frozen_string_literal: true

# The rails_app sample definitions (app/messages) build valid documents from their fixtures.
RSpec.describe CommandTower::Messaging::Definitions::DocumentBuilder, :message_definition_render_context do
  [ClassCanceled, MembershipRenewal, ClassReminder, CheckInReady].each do |definition|
    describe definition.name do
      definition.fixtures.each do |name, metadata|
        it "builds a valid inbox document for the #{name} fixture" do
          expect(described_class.inbox(definition: definition.new, context: context_for(definition, metadata))
            .as_json["root"]["type"]).to eq("card")
        end

        it "builds a headline slot for the #{name} fixture" do
          expect(
            described_class.slots(definition: definition.new, context: context_for(definition, metadata))[:headline]
          ).to be_present
        end
      end

      it "has a metadata schema that accepts its first fixture" do
        expect(definition.metadata_schema.schema_errors(definition.fixtures.values.first)).to be_empty
      end
    end
  end

  it "declares two class_canceled fixtures" do
    expect(ClassCanceled.fixtures.keys.size).to eq(2)
  end

  it "defaults class_canceled to the studio zone" do
    expect(ClassCanceled.default_zone).to eq("America/Los_Angeles")
  end

  it "leaves the sample SMS without the start time" do
    expect(described_class.slots(definition: ClassReminder.new, context: first_context(ClassReminder))[:sms_body])
      .not_to match(/Dec|PST|PM/)
  end

  it "puts the check-in code in the inbox document" do
    expect(described_class.inbox(definition: CheckInReady.new, context: first_context(CheckInReady)).as_json.to_s)
      .to include("482913")
  end

  it "puts the check-in code in the email document, which forces the fallback" do
    expect(described_class.email(definition: CheckInReady.new, context: first_context(CheckInReady)).as_json.to_s)
      .to include("482913")
  end
end
