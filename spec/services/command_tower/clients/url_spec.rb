# frozen_string_literal: true

RSpec.describe CommandTower::Clients::Url do
  describe ".absolute?" do
    subject { described_class.absolute?(url) }

    context "with an absolute HTTP(S) URL" do
      let(:url) { "https://example.test/path" }

      it { is_expected.to be(true) }
    end

    context "with a leading-slash relative path" do
      let(:url) { "/reservations" }

      it { is_expected.to be(false) }
    end

    context "with a path segment relative path" do
      let(:url) { "reservations" }

      it { is_expected.to be(false) }
    end
  end

  describe ".join" do
    subject { described_class.join(base_url, path) }

    context "when the base is a host root and the path is rooted" do
      let(:base_url) { "https://example.test" }
      let(:path) { "/reservations" }

      it { is_expected.to eq("https://example.test/reservations") }
    end

    context "when the base has a trailing slash and the path does not" do
      let(:base_url) { "https://example.test/" }
      let(:path) { "reservations" }

      it { is_expected.to eq("https://example.test/reservations") }
    end

    context "when the base includes a path prefix" do
      let(:base_url) { "https://example.test/api/v1" }
      let(:path) { "/reservations" }

      it { is_expected.to eq("https://example.test/api/v1/reservations") }
    end

    context "when base_url is blank" do
      subject(:invoke) { described_class.join("", "/reservations") }

      it "raises ConfigurationError" do
        expect { invoke }.to raise_error(
          CommandTower::Clients::Errors::ConfigurationError,
          /base_url is required/
        )
      end
    end
  end
end
