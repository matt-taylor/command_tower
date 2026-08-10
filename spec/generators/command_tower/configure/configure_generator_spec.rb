# frozen_string_literal: true

require "rails/generators"
require "generators/command_tower/configure/configure_generator"
require "fileutils"

RSpec.describe CommandTower::ConfigureGenerator do
  let(:destination_root) { Dir.mktmpdir("ct-configure-generator") }

  before do
    FileUtils.mkdir_p(File.join(destination_root, "config"))
    File.write(File.join(destination_root, "config", "routes.rb"), <<~RUBY)
      Rails.application.routes.draw do
      end
    RUBY
  end

  after do
    FileUtils.rm_rf(destination_root)
  end

  let(:silence_stream) do
    lambda do |stream, &block|
      old = stream.dup
      stream.reopen(File::NULL)
      stream.sync = true
      block.call
    ensure
      stream.reopen(old)
      old.close
    end
  end

  let(:run!) do
    lambda do |**opts|
      generator = described_class.new([], opts, destination_root: destination_root)
      silence_stream.call($stdout) { generator.invoke_all }
    end
  end

  it "creates the initializer and mounts the engine" do
    run!.call

    initializer = File.join(destination_root, "config/initializers/command_tower.rb")
    expect(File).to exist(initializer)
    expect(File.read(initializer)).to include("CommandTower.configure")
    expect(File.read(File.join(destination_root, "config/routes.rb"))).to include('mount CommandTower::Engine => "/"')
  end

  it "skips routes when skip_routes is true" do
    run!.call(skip_routes: true)

    expect(File).to exist(File.join(destination_root, "config/initializers/command_tower.rb"))
    expect(File.read(File.join(destination_root, "config/routes.rb"))).not_to include("CommandTower::Engine")
  end

  context "when an initializer already exists without force" do
    let(:path) { File.join(destination_root, "config/initializers/command_tower.rb") }

    before do
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "# custom host initializer\n")
      run!.call
    end

    it "does not overwrite the existing initializer" do
      expect(File.read(path)).to eq("# custom host initializer\n")
    end

    it "overwrites when force is true" do
      run!.call(force: true)
      expect(File.read(path)).to include("CommandTower.configure")
    end
  end

  context "when CommandTower::Engine is already mounted" do
    let(:routes) { File.join(destination_root, "config/routes.rb") }

    before do
      File.write(routes, <<~RUBY)
        Rails.application.routes.draw do
          mount CommandTower::Engine => "/api"
        end
      RUBY
      run!.call
    end

    subject(:contents) { File.read(routes) }

    it "does not mount again" do
      expect(contents.scan("CommandTower::Engine").size).to eq(1)
    end

    it "preserves the existing mount path" do
      expect(contents).to include('mount CommandTower::Engine => "/api"')
    end
  end
end
