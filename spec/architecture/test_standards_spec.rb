# frozen_string_literal: true

# Pragmatic structural guards for Phase 5.7.1–5.7.4 / testing.mdc.
# Excludes: integration_test/** (project exemption), architecture/** (Dir/source
# scans naturally assign in examples), Class.new/controller bodies, HEREDOC
# string contents. This file is excluded from self-scan.
RSpec.describe "CommandTower test standards", :aggregate_failures do
  let(:engine_spec_root) { CommandTower::Engine.root.join("spec") }
  let(:guard_relpath) { "architecture/test_standards_spec.rb" }

  def spec_files
    Dir[engine_spec_root.join("**/*_spec.rb").to_s].sort
  end

  def non_integration_spec_files
    spec_files.reject do |path|
      path.include?("/integration_test/") ||
        path.include?("/architecture/") ||
        Pathname.new(path).relative_path_from(engine_spec_root).to_s == guard_relpath
    end
  end

  it "has no example-group def helpers outside integration_test" do
    offenders = []
    non_integration_spec_files.each do |path|
      defs = CommandTower::TestStandardsScanner.example_group_defs(File.read(path))
      next if defs.empty?

      rel = Pathname.new(path).relative_path_from(engine_spec_root)
      offenders << "#{rel}: #{defs.map { |(_, s)| s }.join('; ')}"
    end
    expect(offenders).to eq([])
  end

  it "does not assign top-level fake Class.new constants in specs" do
    pattern = /^\s*[A-Z]\w*\s*=\s*Class\.new/
    offenders = non_integration_spec_files.filter_map do |path|
      hits = File.readlines(path).each_with_index.filter_map do |line, idx|
        "#{idx + 1}:#{line.strip}" if line.match?(pattern)
      end
      next if hits.empty?

      rel = Pathname.new(path).relative_path_from(engine_spec_root)
      "#{rel} (#{hits.join(', ')})"
    end
    expect(offenders).to eq([])
  end

  it "does not require rails_helper inside individual specs" do
    offenders = spec_files.filter_map do |path|
      next if Pathname.new(path).relative_path_from(engine_spec_root).to_s == guard_relpath
      next unless File.read(path).match?(/require\s+['"]rails_helper['"]/)

      Pathname.new(path).relative_path_from(engine_spec_root).to_s
    end
    expect(offenders).to eq([])
  end

  it "does not use bare double(" do
    offenders = non_integration_spec_files.filter_map do |path|
      hits = CommandTower::TestStandardsScanner.bare_double_hits(path)
      next if hits.empty?

      rel = Pathname.new(path).relative_path_from(engine_spec_root)
      "#{rel} (#{hits.join(', ')})"
    end
    expect(offenders).to eq([])
  end

  it "does not use allow_any_instance_of(" do
    offenders = non_integration_spec_files.filter_map do |path|
      hits = CommandTower::TestStandardsScanner.allow_any_instance_of_hits(path)
      next if hits.empty?

      rel = Pathname.new(path).relative_path_from(engine_spec_root)
      "#{rel} (#{hits.join(', ')})"
    end
    expect(offenders).to eq([])
  end

  it "does not place allow( inside it blocks" do
    offenders = []
    non_integration_spec_files.each do |path|
      hits = CommandTower::TestStandardsScanner.allow_inside_it_offenders(path)
      next if hits.empty?

      rel = Pathname.new(path).relative_path_from(engine_spec_root)
      hits.each { |hit| offenders << "#{rel}:#{hit}" }
    end
    expect(offenders).to eq([])
  end

  it "does not assign local variables inside it blocks" do
    offenders = []
    non_integration_spec_files.each do |path|
      hits = CommandTower::TestStandardsScanner.assign_inside_it_offenders(path)
      next if hits.empty?

      rel = Pathname.new(path).relative_path_from(engine_spec_root)
      hits.each { |hit| offenders << "#{rel}:#{hit}" }
    end
    expect(offenders).to eq([])
  end

  it "does not place scenario setup inside it blocks" do
    offenders = []
    non_integration_spec_files.each do |path|
      hits = CommandTower::TestStandardsScanner.setup_inside_it_offenders(path)
      next if hits.empty?

      rel = Pathname.new(path).relative_path_from(engine_spec_root)
      hits.each { |hit| offenders << "#{rel}:#{hit}" }
    end
    expect(offenders).to eq([])
  end
end
