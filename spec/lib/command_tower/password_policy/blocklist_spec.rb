# frozen_string_literal: true

require "zlib"
require "tmpdir"

RSpec.describe CommandTower::PasswordPolicy::Blocklist, :aggregate_failures do
  after { described_class.reset! }

  describe "bundled list" do
    let(:gemspec) { Gem::Specification.load(File.expand_path("../../../../command_tower.gemspec", __dir__)) }

    it "blocks common passwords case-insensitively" do
      expect(described_class.include?("password")).to be(true)
      expect(described_class.include?("PassWord")).to be(true)
    end

    it "allows an uncommon passphrase" do
      expect(described_class.include?("correct-horse-9f3Qz!battery")).to be(false)
    end

    it "ships inside the gem file list" do
      expect(gemspec.files).to include(
        "lib/command_tower/data/password-blocklist-100k.txt.gz",
        "lib/command_tower/data/NOTICE"
      )
    end
  end

  describe "configured paths" do
    let(:plain_text) { CommandTower.config.login.plain_text }
    let(:dir) { Dir.mktmpdir }
    let(:plain_path) { File.join(dir, "extra.txt") }
    let(:gz_path) { File.join(dir, "extra.txt.gz") }

    before do
      File.write(plain_path, "Hunter2Hunter2\n\n")
      Zlib::GzipWriter.open(gz_path) { |io| io.write("zebra-quartz-77\n") }
      described_class.reset!
    end

    around do |example|
      original = plain_text.password_blocklist_paths
      example.run
    ensure
      plain_text.password_blocklist_paths = original
      FileUtils.remove_entry(dir)
    end

    it "reads plain text and gzipped files and ignores blank lines" do
      plain_text.password_blocklist_paths = [plain_path, gz_path]

      expect(described_class.include?("hunter2hunter2")).to be(true)
      expect(described_class.include?("ZEBRA-quartz-77")).to be(true)
      expect(described_class.include?("")).to be(false)
      expect(described_class.include?("password")).to be(false)
    end
  end
end
