# frozen_string_literal: true

RSpec.describe CommandTower::EmailTheme::TokenFile, :email_theme do
  let(:fixture_path) { File.expand_path("../../../fixtures/messaging/ui_tokens.json", __dir__) }
  let(:valid_tokens) { JSON.parse(File.read(fixture_path)) }

  describe ".load_palette" do
    let(:palette) { described_class.load_palette(fixture_path) }

    it "loads the 31-token shared fixture as a frozen Hash", :aggregate_failures do
      expect(palette).to be_frozen.and include("primary" => "#5c2fc6")
      expect(palette.size).to eq(31)
    end

    it "loads CT's default file" do
      expect(described_class.load_palette(described_class::DEFAULT_PATH).keys)
        .to match_array(CommandTower::EmailTheme::Palette::KEYS)
    end

    {
      "not JSON" => ->(_valid) { "{nope" },
      "not an object" => ->(_valid) { "[]" },
      "wrong version" => ->(valid) { JSON.generate(valid.merge("version" => 2)) },
      "no palette" => ->(_valid) { JSON.generate("version" => 1) },
      "missing key" => ->(valid) { JSON.generate(valid.merge("palette" => valid["palette"].except("danger"))) },
      "bad color" => ->(valid) { JSON.generate(valid.merge("palette" => valid["palette"].merge("primary" => "evil"))) }
    }.each do |name, build|
      context "with #{name}", :tmpdir do
        let(:invalid_path) { write_tokens(tmpdir, build.call(valid_tokens)) }

        it "rejects it without echoing values", :aggregate_failures do
          expect { described_class.load_palette(invalid_path) }
            .to raise_error(described_class::InvalidError) { |error| expect(error.message).not_to include("evil") }
        end
      end
    end

    it "raises InvalidError for a missing file" do
      expect { described_class.load_palette("/nonexistent/ui_tokens.json") }
        .to raise_error(described_class::InvalidError, /could not be read/)
    end
  end

  describe ".validate_host_file!" do
    let(:logger) { instance_double(Logger, warn: nil) }

    before { allow(described_class).to receive(:host_path).and_return(host_path) }

    context "when the host file is missing" do
      let(:host_path) { "/nonexistent/ui_tokens.json" }

      it "warns once" do
        described_class.validate_host_file!(logger:)

        expect(logger).to have_received(:warn).once.with(%r{config/ui_tokens\.json not found})
      end
    end

    context "when the host file is valid" do
      let(:host_path) { fixture_path }

      it "accepts it without warning" do
        described_class.validate_host_file!(logger:)

        expect(logger).not_to have_received(:warn)
      end
    end

    context "when the host file is invalid", :tmpdir do
      let(:host_path) { write_tokens(tmpdir, "{nope") }

      it "raises (boot error)" do
        expect { described_class.validate_host_file!(logger:) }.to raise_error(described_class::InvalidError)
      end
    end
  end
end
