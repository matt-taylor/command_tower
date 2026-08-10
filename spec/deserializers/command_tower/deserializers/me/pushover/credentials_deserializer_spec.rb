# frozen_string_literal: true

RSpec.describe CommandTower::Deserializers::Me::Pushover::CredentialsDeserializer do
  context "with camelCase aliases" do
    subject(:result) do
      described_class.call(
        ActionController::Parameters.new(
          "userKey" => " user-key ",
          "applicationToken" => " app-token "
        )
      )
    end

    it { expect(result).to be_success }
    it { expect(result.input.user_key).to eq("user-key") }
    it { expect(result.input.application_token).to eq("app-token") }
  end

  context "when required fields are blank" do
    subject(:result) { described_class.call(ActionController::Parameters.new("userKey" => "")) }

    it { expect(result).not_to be_success }
  end
end
